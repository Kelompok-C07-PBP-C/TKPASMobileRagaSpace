part of 'package:tk2ragaspace/features/home/home_screen.dart';

@visibleForTesting
typedef TopVenuesHttpGet = Future<http.Response> Function(Uri uri);

@visibleForTesting
TopVenuesHttpGet? topVenuesHttpGetOverride;

mixin _HomeTopVenuesSection on _HomeScreenCore {
  @override
  List<_VenueCardData> get _filteredVenues => _filterVenues(
    _venues,
    city: _selectedCity,
    category: _selectedCategory,
    price: _selectedPrice,
  );

  Widget _buildTopVenuesList() {
    if (_loadingVenues) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_venuesError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: _ErrorNotice(
          title: 'Tidak dapat memuat venue',
          message: _venuesError!,
          actionLabel: _venuesCanRetry ? 'Coba lagi' : null,
          onRetry: _venuesCanRetry ? () => _fetchTopVenues() : null,
        ),
      );
    }
    final filteredVenues = _filteredVenues;
    if (filteredVenues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No venues match these filters.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba pilih kota atau kategori lain, atau tekan "Search venues" untuk jelajahi katalog.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openCatalog(
                initialCity: _selectedCity,
                initialCategory: _selectedCategory,
                initialPrice: _selectedPrice,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FA2FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Browse Catalog'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < filteredVenues.length; i++) ...[
          _FadeSlideIn(
            delay: Duration(milliseconds: 500 + i * 160),
            child: _VenueCard(
              data: filteredVenues[i],
              onTap: () => _openVenueDetail(filteredVenues[i]),
              isFavorite: _wishlistKeys.contains(filteredVenues[i].storageKey),
              onToggleFavorite: () => _toggleWishlist(filteredVenues[i]),
            ),
          ),
          if (i != filteredVenues.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _fetchTopVenues() async {
    if (!mounted) return;
    setState(() {
      _loadingVenues = true;
      _venuesError = null;
      _venuesCanRetry = false;
    });
    try {
      // Use the same API base URL that the rest of the app uses to avoid
      // accidental mismatches (extra /api segments, localhost vs production,
      // etc.).
      final uri = Uri.parse('${Api.defaultBaseUrl}venues/top/?limit=3');
      final response = topVenuesHttpGetOverride != null
          ? await topVenuesHttpGetOverride!(uri)
          : await http
              .get(uri)
              // This endpoint does some synchronization work on the server
              // and can legitimately take a few seconds. Give it a more
              // generous timeout so real users don’t see spurious failures.
              .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Failed to load venues');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final venues = data.map((raw) {
        final dynamic idValue = (raw as Map<String, dynamic>)['id'];
        final parsedId = idValue is int ? idValue : int.tryParse('$idValue');
        return _VenueCardData(
          id: parsedId,
          category: (raw['type'] ?? '').toString(),
          name: (raw['title'] ?? '').toString(),
          location: (raw['location'] ?? '').toString(),
          description: (raw['description'] ?? '').toString(),
          price: int.tryParse(raw['price'].toString()) ?? 0,
          rating: (raw['avg_rating'] ?? 0).toDouble(),
          imageUrl: (raw['image_url'] ?? '').toString(),
          addons: _VenueCardData._parseAddons(raw['addons']),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _venues = venues;
        _loadingVenues = false;
        if (venues.isEmpty) {
          _venuesError =
              'Belum ada venue pada server ini. Tambahkan dari dashboard lalu coba lagi.';
          _venuesCanRetry = true;
        } else {
          _venuesError = null;
          _venuesCanRetry = false;
        }
      });
    } catch (err, stack) {
      // Surface a more helpful error in logs so we can diagnose real
      // failures (bad JSON, wrong URL, etc.) without forcing the user to
      // rely on the generic UI message.
      // ignore: avoid_print
      print('Top venues load failed: $err\n$stack');
      var friendly = err.toString();
      if (friendly.length > 160) {
        friendly = friendly.substring(0, 160);
      }
      if (!mounted) return;
      setState(() {
        _venues = [];
        _loadingVenues = false;
        _venuesError =
            'Tidak bisa memuat data. Detail: $friendly';
        _venuesCanRetry = true;
      });
    }
  }
}

List<_VenueCardData> _filterVenues(
  List<_VenueCardData> venues, {
  String? city,
  String? category,
  String? price,
}) {
  final cityFilter = city ?? _filterCities.first;
  final categoryFilter = category ?? _filterCategories.first;
  final priceFilter = price ?? _filterPrices.first;

  bool matchPrice(int value) {
    if (priceFilter == '< Rp 200k') return value < 200000;
    if (priceFilter == '< Rp 400k') return value < 400000;
    if (priceFilter == '< Rp 600k') return value < 600000;
    if (priceFilter == 'Premium') return value >= 600000;
    return true;
  }

  return venues.where((venue) {
    final cityMatch =
        cityFilter == _filterCities.first ||
        venue.location.toLowerCase().contains(cityFilter.toLowerCase());
    final categoryMatch =
        categoryFilter == _filterCategories.first ||
        venue.category.toLowerCase() == categoryFilter.toLowerCase();
    final priceMatch = matchPrice(venue.price);
    return cityMatch && categoryMatch && priceMatch;
  }).toList();
}

@visibleForTesting
List<Map<String, dynamic>> debugFilterVenuesForTests(
  List<Map<String, dynamic>> rawVenues, {
  String? city,
  String? category,
  String? price,
}) {
  final venues = rawVenues
      .map(
        (m) => _VenueCardData(
          category: (m['category'] ?? '').toString(),
          name: (m['name'] ?? '').toString(),
          location: (m['location'] ?? '').toString(),
          description: (m['description'] ?? '').toString(),
          price: (m['price'] as num?)?.toInt() ?? 0,
          rating: (m['rating'] as num?)?.toDouble() ?? 0,
          imageUrl: (m['imageUrl'] ?? '').toString(),
          id: (m['id'] as num?)?.toInt(),
          addons: const [],
        ),
      )
      .toList();
  final filtered = _filterVenues(
    venues,
    city: city,
    category: category,
    price: price,
  );
  return filtered.map((v) => v.toMap()).toList();
}

class _FilterInput extends StatelessWidget {
  const _FilterInput({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.expand_more, color: Colors.white70),
                dropdownColor: const Color(0xFF0F1D3C),
                isExpanded: true,
                onChanged: onChanged,
                items: options
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
