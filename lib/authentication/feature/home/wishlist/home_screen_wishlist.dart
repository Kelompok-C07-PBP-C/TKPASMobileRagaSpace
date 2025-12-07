part of 'package:tk2ragaspace/features/home/home_screen.dart';

class _WishlistScreen extends StatefulWidget {
  const _WishlistScreen({
    required this.items,
    required this.onRemove,
    required this.onSelect,
    this.loader,
  });

  final List<_VenueCardData> items;
  final Future<void> Function(_VenueCardData) onRemove;
  final ValueChanged<_VenueCardData> onSelect;
  // Optional async loader used to refresh the wishlist from the server after
  final Future<List<_VenueCardData>> Function()? loader;

  @override
  State<_WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<_WishlistScreen> {
  late List<_VenueCardData> _items;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = List<_VenueCardData>.from(widget.items);
    if (widget.loader != null) {
      _refreshFromLoader();
    }
  }

  Future<void> _refreshFromLoader() async {
    setState(() => _loading = _items.isEmpty);
    try {
      final loader = widget.loader;
      if (loader != null) {
        final updated = await loader();
        if (!mounted) return;
        setState(() {
          _items = List<_VenueCardData>.from(updated);
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(_VenueCardData venue) async {
    await widget.onRemove(venue);
    setState(() {
      _items.removeWhere((item) => item.storageKey == venue.storageKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.22)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Wishlist',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading && _items.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : _items.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada venue yang disimpan.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemBuilder: (context, index) {
                            final venue = _items[index];
                            return Dismissible(
                              key: ValueKey(venue.storageKey),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _removeItem(venue),
                              child: _VenueCard(
                                data: venue,
                                onTap: () => widget.onSelect(venue),
                                isFavorite: true,
                                onToggleFavorite: () => _removeItem(venue),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemCount: _items.length,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildWishlistTestApp({
  required List<Map<String, dynamic>> items,
  required Future<void> Function(Map<String, dynamic>) onRemove,
  required ValueChanged<Map<String, dynamic>> onSelect,
}) {
  final mapped = items.map(_VenueCardData.fromMap).toList();
  return MaterialApp(
    home: _WishlistScreen(
      items: mapped,
      onRemove: (venue) => onRemove(venue.toMap()),
      onSelect: (venue) => onSelect(venue.toMap()),
      loader: null,
    ),
  );
}