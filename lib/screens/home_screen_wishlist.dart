part of 'home_screen.dart';

class _WishlistScreen extends StatelessWidget {
  const _WishlistScreen({
    required this.items,
    required this.onRemove,
    required this.onSelect,
  });

  final List<_VenueCardData> items;
  final ValueChanged<_VenueCardData> onRemove;
  final ValueChanged<_VenueCardData> onSelect;

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
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white),
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
                  child: items.isEmpty
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
                            final venue = items[index];
                            return Dismissible(
                              key: ValueKey(venue.storageKey),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  color: Colors.redAccent.withValues(alpha: 0.4),
                                ),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) => onRemove(venue),
                              child: _VenueCard(
                                data: venue,
                                onTap: () => onSelect(venue),
                                isFavorite: true,
                                onToggleFavorite: () => onRemove(venue),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemCount: items.length,
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
