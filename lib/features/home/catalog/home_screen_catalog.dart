part of 'package:tk2ragaspace/features/home/home_screen.dart';

typedef CatalogHttpGet = Future<http.Response> Function(Uri uri);

/// Optional override used in tests to stub the HTTP GET call.
CatalogHttpGet? catalogHttpGetOverride;

class _ProductCatalogScreen extends StatefulWidget {
  const _ProductCatalogScreen({
    required this.initialCity,
    required this.initialCategory,
    required this.initialPrice,
    required this.apiBaseUrl,
    required this.initialWishlistKeys,
    required this.onToggleFavorite,
  });

  final String initialCity;
  final String initialCategory;
  final String initialPrice;
  final String apiBaseUrl;
  final Set<String> initialWishlistKeys;
  final Future<bool> Function(_VenueCardData data) onToggleFavorite;

  @override
  State<_ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<_ProductCatalogScreen> {
  static const String _catalogCacheKeyPrefix = 'catalog_cache:';

  late String _city;
  late String _category;
  late String _price;
  List<_CatalogProduct> _products = const <_CatalogProduct>[];
  bool _loading = true;
  String? _error;
  late Set<String> _favoriteKeys;

  String get _catalogCacheKey {
    final encodedBaseUrl = base64Url.encode(utf8.encode(widget.apiBaseUrl));
    return '$_catalogCacheKeyPrefix$encodedBaseUrl';
  }

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
    _category = widget.initialCategory;
    _price = widget.initialPrice;
    _favoriteKeys = Set<String>.from(widget.initialWishlistKeys);
    _fetchProducts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = _filterProducts();
    final bool showEmpty = !_loading && _error == null && products.isEmpty;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.22)),
          const Positioned.fill(child: _StaticAuroraBackdrop()),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
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
                            'Venue catalog',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: _GlassPanel(
                        padding: const EdgeInsets.all(18),
                        radius: 32,
                        overlayColor: Colors.white.withValues(alpha: 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter venues',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 660;
                                final dropdowns = [
                                  _CatalogDropdown(
                                    label: 'All cities',
                                    value: _city,
                                    items: _filterCities,
                                    onChanged: (value) =>
                                        setState(() => _city = value!),
                                  ),
                                  _CatalogDropdown(
                                    label: 'All categories',
                                    value: _category,
                                    items: _filterCategories,
                                    onChanged: (value) =>
                                        setState(() => _category = value!),
                                  ),
                                  _CatalogDropdown(
                                    label: 'Max price',
                                    value: _price,
                                    items: _filterPrices,
                                    onChanged: (value) =>
                                        setState(() => _price = value!),
                                  ),
                                ];
                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      dropdowns[0],
                                      const SizedBox(height: 16),
                                      dropdowns[1],
                                      const SizedBox(height: 16),
                                      dropdowns[2],
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: dropdowns[0]),
                                    const SizedBox(width: 16),
                                    Expanded(child: dropdowns[1]),
                                    const SizedBox(width: 16),
                                    Expanded(child: dropdowns[2]),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() {}),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.search_rounded),
                                label: Text(
                                  'Search venues',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    if (_loading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 160),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (_error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80),
                          child: _GlassPanel(
                            radius: 28,
                            padding: const EdgeInsets.all(24),
                            overlayColor: Colors.white.withValues(alpha: 0.05),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tidak bisa memuat katalog',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchProducts,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    'Coba lagi',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (showEmpty)
                      SliverToBoxAdapter(
                        child: _GlassPanel(
                          radius: 28,
                          padding: const EdgeInsets.all(20),
                          overlayColor: Colors.white.withValues(alpha: 0.05),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tidak ada venue dengan filter ini.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ubah kota/kategori atau reset filter untuk melihat katalog lainnya.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _resetFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(
                                  'Reset filter',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final product = products[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == products.length - 1 ? 0 : 16,
                            ),
                            child: _CatalogProductCard(
                              product: product,
                              onTap: () => Navigator.of(context).pop(product),
                              isFavorite: _isFavoriteProduct(product),
                              onToggleFavorite: () =>
                                  _toggleProductFavorite(product),
                            ),
                          );
                        }, childCount: products.length),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _city = _filterCities.first;
      _category = _filterCategories.first;
      _price = _filterPrices.first;
    });
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/venues/');
      final getFn = catalogHttpGetOverride ?? http.get;
      http.Response res;
      try {
        res = await getFn(uri).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        res = await getFn(uri).timeout(const Duration(seconds: 25));
      }
      if (res.statusCode != 200) {
        throw Exception('Failed to load venues');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        throw Exception('Unexpected catalog payload');
      }

      final fetched = decoded
          .whereType<Map<String, dynamic>>()
          .map((map) {
            final location = (map['location'] ?? '').toString();
            final city = (map['city'] ?? '').toString();
            return _CatalogProduct(
              id: map['id'] is int
                  ? map['id'] as int
                  : int.tryParse(map['id']?.toString() ?? ''),
              title: (map['title'] ?? '').toString(),
              category: (map['type'] ?? '').toString(),
              city: city.isNotEmpty ? city : (location.split(',').first.trim()),
              description: (map['description'] ?? '').toString(),
              price: int.tryParse(map['price']?.toString() ?? '') ?? 0,
              rating:
                  double.tryParse(map['average_rating']?.toString() ?? '') ?? 0,
              imageUrl: (map['image_url'] ?? '').toString(),
              addons: _VenueCardData._parseAddons(map['addons']),
            );
          })
          .where((product) => product.title.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _products = fetched;
        _loading = false;
      });
      await _cacheCatalogResponse(res.body);
    } catch (err) {
      final cached = await _loadCachedCatalog();
      if (!mounted) return;

      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _products = cached;
          _error = null;
          _loading = false;
        });
        _showCatalogSnack(
          'Menampilkan katalog terakhir. Tarik untuk refresh.',
        );
        return;
      }

      if (_products.isNotEmpty) {
        setState(() {
          _error = null;
          _loading = false;
        });
        _showCatalogSnack(
          'Gagal memperbarui katalog. Tarik untuk refresh.',
        );
        return;
      }

      setState(() {
        _error = 'Tidak bisa memuat katalog. Tarik untuk refresh.';
        _loading = false;
      });
    }
  }

  Future<void> _cacheCatalogResponse(String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_catalogCacheKey, body);
    } catch (_) {
      // ignore cache failures
    }
  }

  Future<List<_CatalogProduct>?> _loadCachedCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_catalogCacheKey);
      if (cached == null || cached.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(cached);
      if (decoded is! List) {
        return null;
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((map) {
            final location = (map['location'] ?? '').toString();
            final city = (map['city'] ?? '').toString();
            return _CatalogProduct(
              id: map['id'] is int
                  ? map['id'] as int
                  : int.tryParse(map['id']?.toString() ?? ''),
              title: (map['title'] ?? '').toString(),
              category: (map['type'] ?? '').toString(),
              city: city.isNotEmpty ? city : (location.split(',').first.trim()),
              description: (map['description'] ?? '').toString(),
              price: int.tryParse(map['price']?.toString() ?? '') ?? 0,
              rating:
                  double.tryParse(map['average_rating']?.toString() ?? '') ?? 0,
              imageUrl: (map['image_url'] ?? '').toString(),
              addons: _VenueCardData._parseAddons(map['addons']),
            );
          })
          .where((product) => product.title.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  void _showCatalogSnack(String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    } catch (_) {
      // ignore if scaffold isn't ready
    }
  }

  List<_CatalogProduct> _filterProducts() {
    return _products.where((product) {
      final dummyVenue = _VenueCardData(
        id: product.id,
        category: product.category,
        name: product.title,
        location: '${product.city}, Indonesia',
        description: product.description,
        price: product.price,
        rating: product.rating,
        imageUrl: product.imageUrl,
        addons: product.addons,
      );
      return _filterVenues(
        [dummyVenue],
        city: _city,
        category: _category,
        price: _price,
      ).isNotEmpty;
    }).toList();
  }

  bool _isFavoriteProduct(_CatalogProduct product) {
    return _favoriteKeys.contains(_productStorageKey(product));
  }

  Future<void> _toggleProductFavorite(_CatalogProduct product) async {
    final venue = _productToVenue(product);
    try {
      final isFavorite = await widget.onToggleFavorite(venue);
      if (!mounted) return;
      final key = _productStorageKey(product);
      setState(() {
        if (isFavorite) {
          _favoriteKeys.add(key);
        } else {
          _favoriteKeys.remove(key);
        }
      });
    } catch (_) {
      // ignore toggle errors for now
    }
  }

  String _productStorageKey(_CatalogProduct product) =>
      _productToVenue(product).storageKey;

  _VenueCardData _productToVenue(_CatalogProduct product) {
    return _VenueCardData(
      id: product.id,
      category: product.category,
      name: product.title,
      location: '${product.city}, Indonesia',
      description: product.description.isNotEmpty
          ? product.description
          : 'Venue ${product.category.toLowerCase()} favorit di ${product.city}.',
      price: product.price,
      rating: product.rating,
      imageUrl: product.imageUrl,
      addons: product.addons,
    );
  }
}

/// Test-only helper to render the catalog screen in isolation.
Widget buildCatalogTestApp({
  String initialCity = 'All cities',
  String initialCategory = 'All categories',
  String initialPrice = 'Any price',
  String apiBaseUrl = 'http://localhost',
  Set<String> initialWishlistKeys = const {},
  Future<bool> Function(Map<String, dynamic> venue)? onToggleFavorite,
}) {
  return MaterialApp(
    home: _ProductCatalogScreen(
      initialCity: initialCity,
      initialCategory: initialCategory,
      initialPrice: initialPrice,
      apiBaseUrl: apiBaseUrl,
      initialWishlistKeys: initialWishlistKeys,
      onToggleFavorite: (venue) async =>
          onToggleFavorite?.call(venue.toMap()) ?? false,
    ),
  );
}

class _CatalogDropdown extends StatelessWidget {
  const _CatalogDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            letterSpacing: 1.5,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.expand_more, color: Colors.white),
              dropdownColor: const Color(0xFF0F1D3C),
              isExpanded: true,
              onChanged: onChanged,
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({
    required this.product,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final _CatalogProduct product;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      overlayColor: Colors.white.withValues(alpha: 0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _buildNetworkImage(product.imageUrl),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _FavoriteBadgeButton(
                    isFavorite: isFavorite,
                    onTap: () {
                      Feedback.forTap(context);
                      onToggleFavorite();
                    },
                    backgroundColor: const Color(0xAA0F1F35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.category.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                letterSpacing: 1.5,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatPriceLabel(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.star_rounded,
                  color: Colors.amber.shade400,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  product.rating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
