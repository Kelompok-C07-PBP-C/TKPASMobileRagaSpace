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
  final Future<List<_VenueCardData>> Function()? loader;

  @override
  State<_WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<_WishlistScreen> {
  late List<_VenueCardData> _items;
  late List<_VenueCardData> _filteredItems;
  bool _loading = false;
  final Map<String, DateTime> _timestamps = {};
  String _sortOrder = 'Urutkan';
  String _ratingOrder = 'Ratings';
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _items = List<_VenueCardData>.from(widget.items);
    _filteredItems = List<_VenueCardData>.from(_items);
    _seedWishlistTimestamps(_items, reset: true);
    _applyWishlistFilters(notify: false);
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
          _seedWishlistTimestamps(_items, reset: true);
          _applyWishlistFilters(notify: false);
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _applyWishlistFilters(notify: false);
        });
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
      _timestamps.remove(venue.storageKey);
      _applyWishlistFilters(notify: false);
    });
  }

  void _seedWishlistTimestamps(
    List<_VenueCardData> source, {
    bool reset = false,
  }) {
    if (reset) {
      _timestamps.clear();
    }
    final now = DateTime.now();
    for (var i = 0; i < source.length; i++) {
      final key = source[i].storageKey;
      _timestamps.putIfAbsent(
        key,
        () => now.subtract(Duration(milliseconds: (source.length - i))),
      );
    }
  }

  // Backwards compatibility for earlier helper names referenced during hot
  // reloads; forwards to the current implementation.
  void _seedTimestamps(List<_VenueCardData> source) {
    _seedWishlistTimestamps(source, reset: false);
  }

  void _applyWishlistFilters({bool notify = true}) {
    final filteredByCategory = _selectedCategory == 'Semua'
        ? List<_VenueCardData>.from(_items)
        : _items
              .where(
                (item) =>
                    item.category.toLowerCase() ==
                    _selectedCategory.toLowerCase(),
              )
              .toList();

    int compareRating(_VenueCardData a, _VenueCardData b) {
      final direction = _ratingOrder == 'Terendah' ? 1 : -1;
      return a.rating.compareTo(b.rating) * direction;
    }

    int compareTimestamp(_VenueCardData a, _VenueCardData b) {
      final timeA =
          _timestamps[a.storageKey] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB =
          _timestamps[b.storageKey] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final direction = _sortOrder == 'Terlama' ? 1 : -1;
      return timeA.compareTo(timeB) * direction;
    }

    filteredByCategory.sort((a, b) {
      final ratingCompare = compareRating(a, b);
      if (ratingCompare != 0) return ratingCompare;
      final timeCompare = compareTimestamp(a, b);
      if (timeCompare != 0) return timeCompare;
      return a.name.compareTo(b.name);
    });

    if (notify) {
      setState(() {
        _filteredItems = filteredByCategory;
      });
    } else {
      _filteredItems = filteredByCategory;
    }
  }

  // Legacy alias to avoid missing references from older builds.
  void _applyFilters({bool notify = true}) {
    _applyWishlistFilters(notify: notify);
  }

  List<Widget> _buildWishlistCategoryFilters() {
    final grouped = <String, List<_VenueCardData>>{};
    for (final item in _items) {
      final category = item.category.isEmpty ? 'Lainnya' : item.category;
      grouped.putIfAbsent(category, () => []).add(item);
    }
    final categories = grouped.keys.toList()..sort();
    return categories
        .map(
          (category) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CategoryFilterChip(
              label: category,
              images: grouped[category]!
                  .map((venue) => venue.imageUrl)
                  .where((url) => url.isNotEmpty)
                  .toList(),
              selected:
                  _selectedCategory.toLowerCase() == category.toLowerCase(),
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                  _applyWishlistFilters(notify: false);
                });
              },
            ),
          ),
        )
        .toList();
  }

  // Legacy alias to mirror previous helper naming.
  List<Widget> _buildCategoryFilters() {
    return _buildWishlistCategoryFilters();
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
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
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _WishlistIconDropdown(
                                label: 'Urutkan',
                                value: _sortOrder,
                                visuals: const {
                                  'Urutkan': _DropdownVisual(
                                    icon: Icons.filter_list_rounded,
                                    color: Colors.white,
                                  ),
                                  'Terlama': _DropdownVisual(
                                    icon: Icons.arrow_downward_rounded,
                                    color: Colors.white,
                                  ),
                                  'Terbaru': _DropdownVisual(
                                    icon: Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                  ),
                                },
                                items: const ['Urutkan', 'Terlama', 'Terbaru'],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _sortOrder = value;
                                    _applyWishlistFilters(notify: false);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _WishlistIconDropdown(
                                label: 'Ratings',
                                value: _ratingOrder,
                                visuals: const {
                                  'Ratings': _DropdownVisual(
                                    icon: Icons.star_rate_rounded,
                                    color: Colors.white,
                                  ),
                                  'Tertinggi': _DropdownVisual(
                                    icon: Icons.star_rate_rounded,
                                    color: Colors.amber,
                                  ),
                                  'Terendah': _DropdownVisual(
                                    icon: Icons.star_rate_rounded,
                                    color: Colors.redAccent,
                                  ),
                                },
                                items: const [
                                  'Ratings',
                                  'Tertinggi',
                                  'Terendah',
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _ratingOrder = value;
                                    _applyWishlistFilters(notify: false);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _GlassPanel(
                          radius: 26,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          overlayColor: Colors.white.withValues(alpha: 0.08),
                          borderColor: Colors.white.withValues(alpha: 0.16),
                          useGradient: false,
                          child: SizedBox(
                            height: 134,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _CategoryFilterChip(
                                  label: 'Semua',
                                  images: const [],
                                  selected: _selectedCategory == 'Semua',
                                  isAll: true,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = 'Semua';
                                      _applyWishlistFilters(notify: false);
                                    });
                                  },
                                ),
                                const SizedBox(width: 12),
                                ..._buildWishlistCategoryFilters(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (_loading && _items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Belum ada venue yang disimpan.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else if (_filteredItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Tidak ada venue yang cocok dengan filter.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 16);
                        }
                        final itemIndex = index ~/ 2;
                        final venue = _filteredItems[itemIndex];
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
                      }, childCount: _filteredItems.length * 2 - 1),
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

class _DropdownVisual {
  const _DropdownVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class _WishlistIconDropdown extends StatelessWidget {
  const _WishlistIconDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.visuals,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final Map<String, _DropdownVisual> visuals;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.plusJakartaSans(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
    final visual = visuals[value] ?? visuals[label] ?? visuals.values.first;
    final activeLabel = items.contains(value) ? value : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: Colors.white),
          dropdownColor: const Color(0xFF0F1D3C),
          onChanged: onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Icon(
                        visuals[item]?.icon ?? visual?.icon,
                        color: visuals[item]?.color ?? Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(item, style: labelStyle),
                    ],
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => items
              .map(
                (_) => Row(
                  children: [
                    Icon(
                      visual?.icon,
                      color: visual?.color ?? Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(activeLabel, style: labelStyle),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.images,
    required this.selected,
    required this.onTap,
    this.isAll = false,
  });

  final String label;
  final List<String> images;
  final bool selected;
  final VoidCallback onTap;
  final bool isAll;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF2CD5FF).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.14);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF1FA2FF), Color(0xFF2CD5FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(color: borderColor),
              color: selected ? null : Colors.white.withValues(alpha: 0.04),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0x331FA2FF),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _CategoryPreview(
                images: images,
                fallbackLabel: label,
                showRagaLogo: isAll,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.images,
    required this.fallbackLabel,
    this.showRagaLogo = false,
  });

  final List<String> images;
  final String fallbackLabel;
  final bool showRagaLogo;

  @override
  Widget build(BuildContext context) {
    if (showRagaLogo) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C4BFF), Color(0xFF34B3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6DDCFF), Color(0xFF7F60F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.sports_kabaddi_rounded,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (images.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            fallbackLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    final display = images.take(4).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        final size = constraints.biggest;
        if (display.length == 1) {
          children.add(
            Positioned.fill(
              child: _buildNetworkImage(display.first, fit: BoxFit.cover),
            ),
          );
        } else if (display.length == 2) {
          final halfHeight = size.height / 2;
          for (var i = 0; i < 2; i++) {
            children.add(
              Positioned(
                top: i * halfHeight,
                left: 0,
                right: 0,
                height: halfHeight,
                child: _buildNetworkImage(display[i], fit: BoxFit.cover),
              ),
            );
          }
        } else {
          final half = size.width / 2;
          for (var i = 0; i < display.length; i++) {
            final row = i < 2 ? 0 : 1;
            final col = i % 2;
            children.add(
              Positioned(
                left: col * half,
                top: row * half,
                width: half,
                height: half,
                child: _buildNetworkImage(display[i], fit: BoxFit.cover),
              ),
            );
          }
        }
        return Stack(children: children);
      },
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
