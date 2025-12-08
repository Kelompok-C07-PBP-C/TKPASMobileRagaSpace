part of 'package:tk2ragaspace/features/home/home_screen.dart';

mixin _HomeHeroSection on _HomeScreenCore {
  Widget _buildHeroHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PENYEWAAN LAPANGAN TERBAIK',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ONLY ON RAGASPACE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Temukan dan sewa lapangan olahraga terbaik di kota Anda dengan mudah dan cepat melalui RagaSpace.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationBar({bool fullBleed = false}) {
    final padding = MediaQuery.of(context).padding;
    final bar = Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B152C),
        border: Border(bottom: BorderSide(color: Color(0x221FA2FF), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        fullBleed ? 20 : 0,
        padding.top + (fullBleed ? 14 : 0),
        fullBleed ? 20 : 0,
        14,
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_ctaBlue, _ctaTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.sports_martial_arts,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RagaSpace',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Premium venues',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: _showProfileMenu,
            borderRadius: BorderRadius.circular(24),
          child: CircleAvatar(
              radius: 16,
              backgroundImage: !homeDisableNetworkImagesForTests &&
                      _avatarUrl != null &&
                      _avatarUrl!.isNotEmpty
                  ? NetworkImage(_avatarUrl!)
                  : null,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
    if (fullBleed) return bar;
    return _GlassPanel(
      radius: 26,
      padding: EdgeInsets.zero,
      overlayColor: Colors.white.withValues(alpha: 0.08),
      child: bar,
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: const Color(0xFF081224),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          if (width >= 680) {
            final bool extraWide = width >= 1024;
            final int itemsPerRow = extraWide ? 5 : 4;
            final double chipWidth =
                ((width - 16 * (itemsPerRow - 1)) / itemsPerRow).clamp(
              140.0,
              220.0,
            );
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _categories
                  .map(
                    (category) => SizedBox(
                      width: chipWidth,
                      child: _CategoryChip(data: category),
                    ),
                  )
                  .toList(),
            );
          }
          final splitPoint = (_categories.length / 2).ceil();
          final rows = [
            _categories.sublist(0, splitPoint),
            _categories.sublist(splitPoint),
          ].where((row) => row.isNotEmpty).toList();
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                  child: SizedBox(
                    height: 64,
                    child: _CategoryMarqueeRow(
                      data: rows[i],
                      animation: _categoryMarqueeController,
                      phase: i * 0.35,
                      reverse: i.isOdd,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchCard() {
    return _GlassPanel(
      radius: 32,
      padding: const EdgeInsets.all(24),
      overlayColor: Colors.white.withValues(alpha: 0.05),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 16.0;
          final double width = constraints.maxWidth;
          final int columns;
          if (width >= 980) {
            columns = 4;
          } else if (width >= 720) {
            columns = 3;
          } else if (width >= 500) {
            columns = 2;
          } else {
            columns = 1;
          }
          final double columnWidth =
              (width - spacing * (columns - 1)) / columns;
          final bool singleColumn = columns == 1;
          final double itemWidth = singleColumn ? width : columnWidth;
          final List<Widget> filters = [
            _FilterInput(
              label: 'All cities',
              value: _selectedCity,
              options: _filterCities,
              icon: Icons.location_on_outlined,
              onChanged: (value) => setState(() => _selectedCity = value!),
            ),
            _FilterInput(
              label: 'All categories',
              value: _selectedCategory,
              options: _filterCategories,
              icon: Icons.watch_later_outlined,
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            _FilterInput(
              label: 'Max price',
              value: _selectedPrice,
              options: _filterPrices,
              icon: Icons.attach_money_rounded,
              onChanged: (value) => setState(() => _selectedPrice = value!),
            ),
          ];
          final children = <Widget>[
            Wrap(
              spacing: spacing,
              runSpacing: 18,
              alignment:
                  singleColumn ? WrapAlignment.center : WrapAlignment.start,
              children: [
                for (final filter in filters)
                  SizedBox(width: itemWidth, child: filter),
                SizedBox(
                  width: singleColumn ? width : itemWidth,
                  child: _buildSearchButton(),
                ),
              ],
            ),
          ];
          final bool showEmptyHint =
              !_loadingVenues &&
                  _venuesError == null &&
                  _filteredVenues.isEmpty &&
                  _venues.isNotEmpty;
          if (showEmptyHint) {
            children.add(const SizedBox(height: 12));
            children.add(
              Text(
                'Tidak ada venue untuk kombinasi filter ini. '
                'Coba ubah kota/kategori atau buka katalog untuk opsi lain.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: const LinearGradient(
            colors: [_ctaBlue, _ctaTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331FA2FF),
              blurRadius: 40,
              spreadRadius: 2,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(36),
          child: InkWell(
            borderRadius: BorderRadius.circular(36),
            onTap: () => _openCatalog(
              initialCity: _selectedCity,
              initialCategory: _selectedCategory,
              initialPrice: _selectedPrice,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 280;
                final double horizontalPadding =
                    constraints.maxWidth < 240 ? 20 : 32;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Search venues',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 12),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: SizedBox(
            height: 420,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/hero_gradient.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              offset: const Offset(0, 0.15),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _buildSearchCard(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double targetWidth = (maxWidth >= 420 ? 340.0 : (maxWidth - 40))
            .clamp(220.0, maxWidth);
        return VisibilityDetector(
          key: _highlightVisibilityKey,
          onVisibilityChanged: (info) {
            final shouldRun = info.visibleFraction > 0.3;
            if (shouldRun && !_highlightAutoplayEnabled) {
              _startHighlightAutoScroll();
            } else if (!shouldRun && _highlightAutoplayEnabled) {
              _pauseHighlightAutoScroll();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(48),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _highlightController,
                padEnds: false,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemCount: _highlightPageCount,
                itemBuilder: (context, index) {
                  final child = index == _highlightCards.length
                      ? const _ExploreVenuesCard()
                      : _HighlightInfoCard(data: _highlightCards[index]);
                  return Align(
                    child: ConstrainedBox(
                      constraints: BoxConstraints.tightFor(width: targetWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget _buildSectionHeader(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Future<void> _openCatalog({
    String? initialCity,
    String? initialCategory,
    String? initialPrice,
  }) async {
    if (_navIndex == 1) return;
    setState(() => _navIndex = 1);
    final selected = await Navigator.of(context).push<_CatalogProduct>(
      AuroraWarpRoute(
        _ProductCatalogScreen(
          initialCity: initialCity ?? _selectedCity,
          initialCategory: initialCategory ?? _selectedCategory,
          initialPrice: initialPrice ?? _selectedPrice,
          apiBaseUrl: _apiBaseUrl,
          initialWishlistKeys: Set<String>.from(_wishlistKeys),
          onToggleFavorite: _toggleWishlistAndReturn,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
    if (selected != null) _openCatalogVenue(selected);
  }

  @override
  Future<void> _openWishlist() async {
    if (_navIndex == 2) return;
    setState(() => _navIndex = 2);
    await Navigator.of(context).push(
      AuroraWarpRoute(
        _WishlistScreen(
          items: _wishlist,
          onRemove: _toggleWishlist,
          onSelect: (venue) => _openVenueDetail(venue),
          loader: _syncWishlistForScreen,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
  }

  @override
  Future<void> _openBookings() async {
    if (_navIndex == 3) return;
    setState(() => _navIndex = 3);
    await Navigator.of(context).push(
      AuroraWarpRoute(
        _BookingsScreen(
          loadBookings: _fetchBookingsFromServer,
          onSelectBooking: (booking) {
            final venue = _bookingToVenueCard(booking);
            _openVenueDetail(venue);
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
  }

  @override
  Future<void> _openVenueDetail(_VenueCardData data) async {
    final isFavorite = _wishlistKeys.contains(data.storageKey);
    await Navigator.of(context).push(
      AuroraWarpRoute(
        _VenueDetailLoadingScreen(
          data: data,
          apiBaseUrl: _apiBaseUrl,
          isFavorite: isFavorite,
          accountPhoneNumber: _accountPhoneNumber,
          onToggleFavorite: _toggleWishlistAndReturn,
        ),
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(16),
        child: _GlassPanel(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8),
          overlayColor: const Color(0xF0141E2F),
          borderColor: Colors.white.withValues(alpha: 0.18),
          useGradient: false,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    'Account settings',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Update profile & preferences',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openAccountSettings();
                  },
                ),
                const Divider(height: 0, color: Color(0x33FFFFFF)),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    'Log out',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Sign out',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _performLogout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAccountSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()))
        .then((_) {
      _loadProfileSummary();
    });
  }

  Future<void> _performLogout() async {
    if (!mounted) return;
    // Navigate away from the home shell immediately so the UI feels snappy.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );

    // Perform the server-side logout in the background. Even if this fails,
    // the user is already back on the login screen and the local "remember me"
    // state will be cleared by Api.logout.
    // ignore: unawaited_futures
    () async {
      try {
        await Api().logout();
      } catch (_) {
        // deliberately ignored
      }
    }();
  }

  Future<List<_BookingSummary>> _fetchBookingsFromServer() async {
    final username = Api.currentUsername;
    Uri uri = Uri.parse('$_apiBaseUrl/api/bookings/');
    if (username != null && username.isNotEmpty) {
      uri = uri.replace(queryParameters: {'username': username});
    }
    // Let the HTTP client decide its own connection timeout so we don't
    // prematurely fail on slower networks. The bookings endpoint can do some
    // synchronization work on the server and may legitimately take several
    // seconds to respond.
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      // ignore: avoid_print
      print(
          'Bookings fetch failed (${response.statusCode}): ${response.body}');
      throw Exception('Status code ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((raw) => _BookingSummary.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  _VenueCardData _bookingToVenueCard(_BookingSummary booking) {
    final description = booking.venueDescription.isNotEmpty
        ? booking.venueDescription
        : 'Nikmati sesi terbaikmu di ${booking.venueName}.';
    final location = booking.venueLocation.isNotEmpty
        ? booking.venueLocation
        : 'Lokasi belum tersedia';
    return _VenueCardData(
      id: booking.venueId == 0 ? null : booking.venueId,
      category: booking.venueType.isNotEmpty ? booking.venueType : 'Venue',
      name: booking.venueName,
      location: location,
      description: description,
      price: booking.venuePrice,
      rating: 0,
      imageUrl: booking.venueImageUrl,
      addons: booking.venueAddons,
    );
  }

  void _openCatalogVenue(_CatalogProduct product) {
    _openVenueDetail(_catalogProductToVenue(product));
  }

  _VenueCardData _catalogProductToVenue(_CatalogProduct product) {
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
