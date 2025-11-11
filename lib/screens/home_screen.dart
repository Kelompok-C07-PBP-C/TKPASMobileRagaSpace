import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:marco/services/api.dart';
import 'package:marco/widgets/aurora_route.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'home_screen_models.dart';
part 'home_screen_catalog.dart';
part 'home_screen_wishlist.dart';
part 'home_screen_bookings.dart';
part 'home_screen_widgets.dart';

const _backgroundGradient = LinearGradient(
  colors: [
    Color(0xFF0A1226), // base navy from reference
    Color(0xFF0D1B32),
    Color(0xFF12325A),
    Color(0xFF1F4D7A),
  ],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);
const _ctaBlue = Color(0xFF1FA2FF);
const _ctaTeal = Color(0xFF2CD5FF);
const _imageFallbackGradient = LinearGradient(
  colors: [Color(0xFF132548), Color(0xFF1E3C6B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _wishlistStorageKey = 'wishlist_venues';
const List<String> _filterCities = [
  'All cities',
  'Jakarta',
  'Bandung',
  'Surabaya',
  'Bali',
];
const List<String> _filterCategories = [
  'All categories',
  'Futsal',
  'Badminton',
  'Basket',
  'Tennis',
];
const List<String> _filterPrices = [
  'Any price',
  '< Rp 200k',
  '< Rp 400k',
  '< Rp 600k',
  'Premium',
];

Widget _buildNetworkImage(String url, {BoxFit fit = BoxFit.cover}) {
  final placeholder = DecoratedBox(
    decoration: const BoxDecoration(gradient: _imageFallbackGradient),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white70),
    ),
  );
  if (url.isEmpty) return placeholder;
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return placeholder;
    },
    errorBuilder: (_, __, ___) => placeholder,
  );
}

String _resolveApiBaseUrl() {
  const envOverride = String.fromEnvironment('API_BASE_URL');
  if (envOverride.isNotEmpty) return envOverride;
  if (kIsWeb) return 'http://localhost:8000';
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static final String _apiBaseUrl = _resolveApiBaseUrl();
  static const List<_CategoryChipData> _categories = [
    _CategoryChipData(label: 'Tennis', icon: Icons.sports_tennis),
    _CategoryChipData(label: 'Badminton', icon: Icons.sports),
    _CategoryChipData(label: 'Basket', icon: Icons.sports_basketball),
    _CategoryChipData(label: 'Sepak bola', icon: Icons.sports_soccer),
    _CategoryChipData(label: 'Padel', icon: Icons.sports_tennis_outlined),
    _CategoryChipData(label: 'Volley Ball', icon: Icons.sports_volleyball),
    _CategoryChipData(label: 'Mini Soccer', icon: Icons.sports_soccer_outlined),
    _CategoryChipData(label: 'Futsal', icon: Icons.sports_soccer_rounded),
    _CategoryChipData(label: 'Billiard', icon: Icons.pool),
    _CategoryChipData(label: 'Tenis Meja', icon: Icons.sports_tennis),
  ];
  static const List<_HighlightCardData> _highlightCards = [
    _HighlightCardData(
      title: '50+ Venues',
      subtitle: 'Across Indonesia',
      gradient: [Color(0xFF3EC9FF), Color(0xFF5B7CFF)],
      icon: Icons.domain_add_rounded,
    ),
    _HighlightCardData(
      title: '5+ Sports',
      subtitle: 'All skill levels',
      gradient: [Color(0xFFFF7E79), Color(0xFFFFC15E)],
      icon: Icons.sports_martial_arts,
    ),
    _HighlightCardData(
      title: 'New Add-ons',
      subtitle: 'Weekly updates',
      gradient: [Color(0xFF46E4C1), Color(0xFF23A8E0)],
      icon: Icons.auto_awesome,
    ),
  ];
  static const List<_PromoCardData> _promoCards = [
    _PromoCardData(
      title: 'Cara Booking Kilat',
      description:
          'Cari venue favoritmu, pilih jadwal yang kosong, lalu konfirmasi pembayaran dalam hitungan detik.',
      bullets: [
        'Filter tipe olahraga, kota, dan harga.',
        'Lihat slot realtime & pilih jadwal.',
        'Checkout aman—invoice otomatis dikirim.',
      ],
      gradient: [Color(0xFF4F46E5), Color(0xFF9337FF)],
      icon: Icons.flash_on_rounded,
    ),
    _PromoCardData(
      title: 'Tips Maksimalkan Analytics',
      description:
          'Pantau okupansi, temukan jam sepi, dan luncurkan promo kilat langsung dari dashboard.',
      bullets: [
        'Notifikasi tren mingguan dikirim via email.',
        'Grafik realtime untuk tiap venue.',
        'Buat promo & broadcast dalam 1 klik.',
      ],
      gradient: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      icon: Icons.auto_graph_rounded,
    ),
  ];

  List<_VenueCardData> _venues = [];
  bool _loadingVenues = true;
  String? _venuesError;
  bool _venuesCanRetry = false;
  String _selectedCity = _filterCities.first;
  String _selectedCategory = _filterCategories.first;
  String _selectedPrice = _filterPrices.first;
  List<_VenueCardData> get _filteredVenues => _filterVenues(
        _venues,
        city: _selectedCity,
        category: _selectedCategory,
        price: _selectedPrice,
      );
  List<_VenueCardData> _wishlist = [];
  Set<String> _wishlistKeys = {};
  SharedPreferences? _prefs;
  static const List<_TestimonialData> _testimonials = [
    _TestimonialData(
      name: 'RPM Dimaz',
      role: 'Manajer Operasional Klub Badminton Orion',
      quote:
          'Dulu kami kesulitan memonitor jam sewa di semua lapangan. Sekarang jadwal terpusat dan anggota klub bisa booking sesuai slot yang kami buka. Laporan transaksi bulanan rapi, jadi mudah untuk evaluasi promo membership.',
      avatarUrl:
          'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=crop&w=600&q=80',
    ),
    _TestimonialData(
      name: 'Gita Hardiman',
      role: 'Founder Urban Volley Hub',
      quote:
          'Dashboard occupancy yang real-time bikin kami gampang mengisi slot low season dengan promo kilat. Tim marketing juga suka karena semua materi tersedia otomatis.',
      avatarUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=600&q=80',
    ),
    _TestimonialData(
      name: 'Darius Mahendra',
      role: 'Head Coach Ironclad Futsal Academy',
      quote:
          'RagaSpace mengurangi pekerjaan admin hampir 40%. Orang tua bisa cek jadwal latihan sendiri dan pembayaran tercatat jelas, jadi kami fokus ke program latihan.',
      avatarUrl:
          'https://images.unsplash.com/photo-1502767040390-9db91f1e91c9?auto=format&fit=crop&w=600&q=80',
    ),
    _TestimonialData(
      name: 'Nina Lesmana',
      role: 'Event Lead Sphere Badminton Club',
      quote:
          'Automasi notifikasi reminder benar-benar menolong saat kami mengelola turnamen komunitas. Semua peserta dapat info timeslot tanpa harus dihubungi manual satu-satu.',
      avatarUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=600&q=80',
    ),
  ];
  final PageController _testimonialController = PageController(
    viewportFraction: 0.9,
  );
  late final PageController _highlightController;
  Timer? _highlightTimer;
  Timer? _testimonialTimer;
  late final AnimationController _backgroundController;
  late final ScrollController _scrollController;
  int _navIndex = 0;
  int _testimonialPage = 0;
 bool _stickyNavVisible = false;
  @override
  void initState() {
    super.initState();
    _highlightController = PageController(viewportFraction: 0.82);
    _startHighlightAutoScroll();
    _startTestimonialAutoScroll();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _fetchTopVenues();
    _loadWishlist();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _testimonialTimer?.cancel();
    _highlightController.dispose();
    _testimonialController.dispose();
    _backgroundController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildCentralFab(),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (_, __) =>
                  _AuroraBackdrops(phase: _backgroundController.value),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 96),
                  _buildHeroHeading(),
                  const SizedBox(height: 20),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: _buildCategoryChips(),
                  ),
                  const SizedBox(height: 90),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 250),
                      child: _buildHeroBanner(),
                  ),
                  const SizedBox(height: 30),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 400),
                    child: _buildHighlightsSection(),
                  ),
                  const SizedBox(height: 48),
                  _buildSectionHeader(
                    'Top 3 Venues',
                    'Handpicked places loved by the RagaSpace community.',
                  ),
                  const SizedBox(height: 20),
                  _buildTopVenuesList(),
                  const SizedBox(height: 48),
                  _buildSectionHeader('What they said about RagaSpace?', null),
                  const SizedBox(height: 16),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 900),
                    child: _buildTestimonialsSection(),
                  ),
                  const SizedBox(height: 48),
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 1050),
                    child: _buildPromoSpotlight(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              offset: _stickyNavVisible ? Offset.zero : const Offset(0, -0.4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _stickyNavVisible ? 1 : 0,
                child: _buildNavigationBar(fullBleed: true),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

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
        border: Border(
          bottom: BorderSide(color: Color(0x221FA2FF), width: 1),
        ),
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
                child: const Icon(Icons.sports_martial_arts, color: Colors.white),
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
          IconButton(
            tooltip: 'Search',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white),
          ),
          CircleAvatar(
            radius: 16,
            backgroundImage: const NetworkImage(
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=200&q=60',
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
    if (fullBleed) {
      return bar;
    }
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
        gradient: const LinearGradient(
          colors: [Color(0xFF07152A), Color(0xFF0C2541)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
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
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      itemBuilder: (context, index) => SizedBox(
                        width: 150,
                        child: _CategoryChip(data: rows[i][index]),
                      ),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: rows[i].length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _startHighlightAutoScroll() {
    _highlightTimer?.cancel();
    final totalPages = _highlightPageCount;
    if (totalPages <= 1) return;
    _highlightTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_highlightController.hasClients) return;
      final currentPage = _highlightController.page?.round() ?? 0;
      final nextPage = (currentPage + 1) % totalPages;
      _highlightController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }


  int get _highlightPageCount => _highlightCards.length + 1;
  void _startTestimonialAutoScroll() {
    _testimonialTimer?.cancel();
    if (_testimonials.length <= 1) return;
    _testimonialTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_testimonialController.hasClients) return;
      final next = (_testimonialPage + 1) % _testimonials.length;
      _testimonialController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _openVenueDetail(_VenueCardData data) {
    Navigator.of(context).push(
      AuroraWarpRoute(
        _VenueDetailLoadingScreen(
          data: data,
          apiBaseUrl: _apiBaseUrl,
        ),
      ),
    );
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > 40;
    if (shouldShow != _stickyNavVisible) {
      setState(() => _stickyNavVisible = shouldShow);
    }
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
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: _imageFallbackGradient),
                ),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cari venue terbaik untuk sesi berikutnya.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Filter kota, kategori, dan anggaranmu di satu tempat.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(child: Container(height: 200)),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 15,
          child: _FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            offset: const Offset(0, 0.15),
            child: _buildSearchCard(),
          ),
        ),
      ],
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
              alignment: WrapAlignment.start,
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
          final bool showEmptyHint = !_loadingVenues &&
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Search venues',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 35,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: SizedBox(
        height: 320,
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: child,
            );
          },
        ),
      ),
    );
  }

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

  Widget _buildTestimonialsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth < 560;
        final double cardHeight = _estimateTestimonialHeight(
          constraints.maxWidth,
          stacked,
        );
        return Column(
          children: [
            SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _testimonialController,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                itemCount: _testimonials.length,
                onPageChanged: (index) {
                  setState(() => _testimonialPage = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _TestimonialCard(
                      data: _testimonials[index],
                      stacked: stacked,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _buildTestimonialControls(),
          ],
        );
      },
    );
  }

  double _estimateTestimonialHeight(double width, bool stacked) {
    const double horizontalPadding = 56; // 28 * 2
    const double verticalPadding = 64; // 32 * 2
    const double avatarSize = 96;
    const double avatarGap = 24;
    final double textWidth = math.max(
      140,
      width - horizontalPadding - (stacked ? 0 : avatarSize + avatarGap),
    );
    final nameStyle = GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final roleStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
      color: Colors.white70,
    );
    final quoteStyle = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      height: 1.6,
      color: Colors.white.withValues(alpha: 0.88),
    );
    double maxTextBlockHeight = 0;
    for (final testimonial in _testimonials) {
      final quoteHeight = _measureTextHeight(
        testimonial.quote,
        quoteStyle,
        textWidth,
      );
      final nameHeight = _measureTextHeight(
        testimonial.name,
        nameStyle,
        textWidth,
      );
      final roleHeight = _measureTextHeight(
        testimonial.role.toUpperCase(),
        roleStyle,
        textWidth,
      );
      final blockHeight = nameHeight + 4 + roleHeight + 12 + quoteHeight;
      maxTextBlockHeight = math.max(maxTextBlockHeight, blockHeight);
    }
    final double contentHeight = stacked
        ? avatarSize + 18 + maxTextBlockHeight
        : math.max(avatarSize, maxTextBlockHeight);
    final double safety = stacked ? 70 : 40;
    return contentHeight + verticalPadding + safety;
  }

  double _measureTextHeight(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  Widget _buildTestimonialControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: List.generate(_testimonials.length, (index) {
            final bool isActive = index == _testimonialPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              height: 8,
              width: isActive ? 28 : 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
        Row(
          children: [
            _buildCircleButton(
              icon: Icons.chevron_left,
              onTap: _testimonials.length > 1 ? _previousTestimonial : null,
            ),
            const SizedBox(width: 12),
            _buildCircleButton(
              icon: Icons.chevron_right,
              onTap: _testimonials.length > 1 ? _nextTestimonial : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, VoidCallback? onTap}) {
    final button = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, color: Colors.white),
    );
    if (onTap == null) {
      return Opacity(opacity: 0.35, child: button);
    }
    return GestureDetector(onTap: onTap, child: button);
  }

  void _nextTestimonial() {
    final next = (_testimonialPage + 1) % _testimonials.length;
    _goToTestimonial(next);
  }

  void _previousTestimonial() {
    final prev = _testimonialPage == 0
        ? _testimonials.length - 1
        : _testimonialPage - 1;
    _goToTestimonial(prev);
  }

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
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
    if (selected != null) _openCatalogVenue(selected);
  }

  Future<void> _openWishlist() async {
    if (_navIndex == 2) return;
    if (_wishlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada venue di wishlist.')),
      );
      return;
    }
    setState(() => _navIndex = 2);
    await Navigator.of(context).push(
      AuroraWarpRoute(
        _WishlistScreen(
          items: _wishlist,
          onRemove: _toggleWishlist,
          onSelect: (venue) => _openVenueDetail(venue),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
  }

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

  Future<List<_BookingSummary>> _fetchBookingsFromServer() async {
    final username = Api.currentUsername;
    Uri uri = Uri.parse('$_apiBaseUrl/api/bookings/');
    if (username != null && username.isNotEmpty) {
      uri = uri.replace(queryParameters: {'username': username});
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat daftar booking');
    }
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map(
          (raw) =>
              _BookingSummary.fromJson(raw as Map<String, dynamic>),
        )
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
      category:
          booking.venueType.isNotEmpty ? booking.venueType : 'Venue',
      name: booking.venueName,
      location: location,
      description: description,
      price: booking.venuePrice,
      rating: 0,
      imageUrl: booking.venueImageUrl,
    );
  }

  void _openCatalogVenue(_CatalogProduct product) {
    _openVenueDetail(_catalogProductToVenue(product));
  }

  _VenueCardData _catalogProductToVenue(_CatalogProduct product) {
    return _VenueCardData(
      id: null,
      category: product.category,
      name: product.title,
      location: '${product.city}, Indonesia',
      description:
          'Venue ${product.category.toLowerCase()} favorit di ${product.city}.',
      price: product.price,
      rating: product.rating,
      imageUrl: product.imageUrl,
    );
  }

  void _goToTestimonial(int index) {
    if (!_testimonialController.hasClients || _testimonials.length <= 1) return;
    _testimonialController.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
              isFavorite:
                  _wishlistKeys.contains(filteredVenues[i].storageKey),
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
      final uri = Uri.parse('$_apiBaseUrl/api/venues/top/?limit=3');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw Exception('Failed to load venues');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final venues = data
          .map(
            (raw) {
              final dynamic idValue = (raw as Map<String, dynamic>)['id'];
              final parsedId =
                  idValue is int ? idValue : int.tryParse('$idValue');
              return _VenueCardData(
                id: parsedId,
                category: (raw['type'] ?? '').toString(),
                name: (raw['title'] ?? '').toString(),
                location: (raw['location'] ?? '').toString(),
                description: (raw['description'] ?? '').toString(),
                price: int.tryParse(raw['price'].toString()) ?? 0,
                rating: (raw['avg_rating'] ?? 0).toDouble(),
                imageUrl: (raw['image_url'] ?? '').toString(),
              );
            },
          )
          .toList();
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
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _venues = [];
        _loadingVenues = false;
        _venuesError =
            'Tidak bisa memuat data. Pastikan backend berjalan dan server dapat diakses dari aplikasi ini.';
        _venuesCanRetry = true;
      });
    }
  }

  Future<void> _loadWishlist() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs!.getStringList(_wishlistStorageKey) ?? [];
    final parsed = stored
        .map((item) => _VenueCardData.fromMap(jsonDecode(item)))
        .toList();
    setState(() {
      _wishlist = parsed;
      _wishlistKeys = parsed.map((e) => e.storageKey).toSet();
    });
  }

  Future<void> _persistWishlist() async {
    _prefs ??= await SharedPreferences.getInstance();
    final encoded = _wishlist.map((e) => jsonEncode(e.toMap())).toList();
    await _prefs!.setStringList(_wishlistStorageKey, encoded);
  }

  Future<void> _toggleWishlist(_VenueCardData data) async {
    final key = data.storageKey;
    setState(() {
      if (_wishlistKeys.contains(key)) {
        _wishlist.removeWhere((item) => item.storageKey == key);
        _wishlistKeys.remove(key);
      } else {
        _wishlist.add(data);
        _wishlistKeys.add(key);
      }
    });
    await _persistWishlist();
  }

  Widget _buildPromoSpotlight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Mulai Lebih Pintar',
          'Panduan singkat & promo instan supaya operasionalmu makin lancar.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            final itemWidth =
                isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _promoCards
                  .map(
                    (data) => SizedBox(
                      width: itemWidth,
                      child: _PromoCard(data: data),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCentralFab() {
    return SizedBox(
      height: 70,
      width: 70,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_ctaBlue, _ctaTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {},
                child: const Center(
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final items = [
      _NavItemData(icon: Icons.home_rounded, label: 'Home'),
      _NavItemData(icon: Icons.grid_view_rounded, label: 'Catalog'),
      _NavItemData(icon: Icons.favorite_border_rounded, label: 'Wishlist'),
      _NavItemData(icon: Icons.event_available_outlined, label: 'Booked'),
    ];
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101F44),
        border: Border(top: BorderSide(color: Color(0x33132142), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            data: items[0],
            selected: _navIndex == 0,
            onTap: () => setState(() => _navIndex = 0),
          ),
          _NavItem(
            data: items[1],
            selected: _navIndex == 1,
            onTap: _openCatalog,
          ),
          const SizedBox(width: 70),
          _NavItem(
            data: items[2],
            selected: _navIndex == 2,
            onTap: _openWishlist,
          ),
          _NavItem(
            data: items[3],
            selected: _navIndex == 3,
            onTap: _openBookings,
          ),
        ],
      ),
    );
  }
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

class _HighlightInfoCard extends StatelessWidget {
  const _HighlightInfoCard({required this.data});

  final _HighlightCardData data;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(20),
      overlayColor: data.gradient.first.withValues(alpha: 0.18),
      borderColor: data.gradient.last.withValues(alpha: 0.4),
      boxShadow: [
        BoxShadow(
          color: data.gradient.last.withValues(alpha: 0.28),
          blurRadius: 35,
          offset: const Offset(0, 20),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: Colors.white, size: 28),
          const Spacer(),
          Text(
            data.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(24),
    this.overlayColor = const Color(0x3310213A),
    this.borderColor,
    this.boxShadow,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color overlayColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: overlayColor,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 20),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ExploreVenuesCard extends StatelessWidget {
  const _ExploreVenuesCard();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(24),
      overlayColor: const Color(0x3314294D),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF46E4C1), Color(0xFF23A8E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.explore_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Explore curated venues',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tim kami memilih venue dengan rating terbaik, fasilitas terawat, dan pengalaman booking paling mulus.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Flexible(
                  child: Text(
                    'Lihat panduan lengkap',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<_VenueCardData> _filterVenues(List<_VenueCardData> venues,
    {String? city, String? category, String? price}) {
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
    final cityMatch = cityFilter == _filterCities.first ||
        venue.location.toLowerCase().contains(cityFilter.toLowerCase());
    final categoryMatch = categoryFilter == _filterCategories.first ||
        venue.category.toLowerCase() == categoryFilter.toLowerCase();
    final priceMatch = matchPrice(venue.price);
    return cityMatch && categoryMatch && priceMatch;
  }).toList();
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.data, required this.stacked});
  final _TestimonialData data;
  final bool stacked;
  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 100,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF43D6FF), Color(0xFF1E6EEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: Image.network(data.avatarUrl, fit: BoxFit.cover),
        ),
      ),
    );
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.role.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.quote,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
    final child = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: avatar),
              const SizedBox(height: 20),
              textBlock,
            ],
          )
        : Row(
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: textBlock),
            ],
          );
    return _GlassPanel(
      radius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      overlayColor: const Color(0x330C1E33),
      child: child,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.data});
  final _CategoryChipData data;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0x3328C4FF), Color(0x12258DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(data.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBackdrops extends StatelessWidget {
  const _AuroraBackdrops({required this.phase});
  final double phase;
  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * 2 * math.pi);
    final swell = math.cos(phase * 2 * math.pi);
    return IgnorePointer(
      child: Stack(
        children: [
          _Halo(
            alignment: Alignment(-1.05 + wave * 0.18, -0.85 + swell * 0.07),
            size: 420 + swell * 38,
            colors: const [Color(0x3333478E), Color(0x00070D1C)],
            shadowColor: const Color(0x2233478E),
            blur: 140,
            spread: 14,
          ),
          _Halo(
            alignment: Alignment(0.95 + swell * 0.22, -0.78 + wave * 0.05),
            size: 360 + wave * 40,
            colors: const [Color(0x44FF8EC7), Color(0x00070D1C)],
            shadowColor: const Color(0x22FF8EC7),
            blur: 150,
            spread: 16,
          ),
          _Halo(
            alignment: Alignment(-0.35 + wave * 0.15, 0.1 + swell * 0.1),
            size: 300 + swell * 40,
            colors: const [Color(0x22475B94), Color(0x00070D1C)],
            shadowColor: const Color(0x22475B94),
            blur: 140,
            spread: 12,
          ),
          _Halo(
            alignment: Alignment(0.35 + swell * 0.18, -0.05 + wave * 0.08),
            size: 280 + wave * 35,
            colors: const [Color(0x22355FB5), Color(0x00070D1C)],
            shadowColor: const Color(0x1A46E4C1),
            blur: 140,
            spread: 12,
          ),
          _Halo(
            alignment: Alignment(0.05 + wave * 0.12, 0.7 + swell * 0.08),
            size: 520 + wave * 56,
            colors: const [Color(0x22304D8E), Color(0x00070D1C)],
            shadowColor: const Color(0x1A304D8E),
            blur: 200,
            spread: 14,
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _AuroraCurtainPainter(phase: phase),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _NebulaParticlePainter(phase: phase),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Color(0x1517314F),
                    Colors.transparent,
                    Color(0x0F0A1C36),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({
    required this.alignment,
    required this.size,
    required this.colors,
    required this.shadowColor,
    required this.blur,
    required this.spread,
  });
  final Alignment alignment;
  final double size;
  final List<Color> colors;
  final Color shadowColor;
  final double blur;
  final double spread;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors, stops: const [0.0, 1.0]),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: blur,
              spreadRadius: spread,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuroraCurtainPainter extends CustomPainter {
  const _AuroraCurtainPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(phase * 2 * math.pi);
    final swell = math.cos(phase * 2 * math.pi);
    const specs = [
      _CurtainSpec(
        verticalFactor: 0.18,
        height: 240,
        horizontalShift: -180,
        waveShift: 26,
        swellShift: 40,
        blur: 80,
        colors: [Color(0x3338D0FF), Color(0x00112A40)],
      ),
      _CurtainSpec(
        verticalFactor: 0.42,
        height: 260,
        horizontalShift: -80,
        waveShift: 20,
        swellShift: -30,
        blur: 70,
        colors: [Color(0x3323FFC3), Color(0x000C1F2F)],
      ),
      _CurtainSpec(
        verticalFactor: 0.68,
        height: 220,
        horizontalShift: -140,
        waveShift: 16,
        swellShift: 55,
        blur: 85,
        colors: [Color(0x332AD7FF), Color(0x00081423)],
      ),
    ];

    for (final spec in specs) {
      final baseY = size.height * spec.verticalFactor +
          wave * spec.waveShift +
          swell * (spec.waveShift * 0.2);
      final left = spec.horizontalShift + swell * spec.swellShift;
      final rect = Rect.fromLTWH(left, baseY, size.width + 280, spec.height);
      final crest = wave * 40;
      final trough = swell * 30;
      final path = Path()
        ..moveTo(rect.left, rect.top + 20)
        ..cubicTo(
          rect.left + rect.width * 0.25,
          rect.top - 50 - crest,
          rect.left + rect.width * 0.6,
          rect.top + 60 + trough,
          rect.right,
          rect.top + 12,
        )
        ..lineTo(rect.right, rect.bottom - 16)
        ..cubicTo(
          rect.left + rect.width * 0.65,
          rect.bottom + 50 + crest * 0.6,
          rect.left + rect.width * 0.2,
          rect.bottom - 30 - trough,
          rect.left,
          rect.bottom + 14,
        )
        ..close();

      final paint = Paint()
        ..shader = LinearGradient(
          colors: spec.colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, spec.blur)
        ..blendMode = BlendMode.plus;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraCurtainPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

class _CurtainSpec {
  const _CurtainSpec({
    required this.verticalFactor,
    required this.height,
    required this.horizontalShift,
    required this.waveShift,
    required this.swellShift,
    required this.blur,
    required this.colors,
  });

  final double verticalFactor;
  final double height;
  final double horizontalShift;
  final double waveShift;
  final double swellShift;
  final double blur;
  final List<Color> colors;
}

class _NebulaParticlePainter extends CustomPainter {
  _NebulaParticlePainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final seeds = [
      const Offset(0.15, 0.2),
      const Offset(0.35, 0.7),
      const Offset(0.65, 0.4),
      const Offset(0.85, 0.75),
      const Offset(0.55, 0.15),
    ];
    for (var i = 0; i < seeds.length; i++) {
      final pulsate = 0.5 + 0.5 * math.sin((phase + i * 0.2) * math.pi * 2);
      final radius = 30 + 18 * pulsate;
      final center = Offset(
        seeds[i].dx * size.width,
        seeds[i].dy * size.height,
      );
      paint.color = Colors.white.withValues(alpha: 0.07 + pulsate * 0.04);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaParticlePainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: selected ? Colors.white : Colors.white70),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.12),
  });
  final Widget child;
  final Duration delay;
  final Offset offset;
  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;
  late final Key _visibilityKey;
  @override
  void initState() {
    super.initState();
    _visibilityKey = UniqueKey();
  }

  Future<void> _trigger() async {
    if (_visible) return;
    await Future.delayed(widget.delay);
    if (mounted) {
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 650);
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!_visible && info.visibleFraction > 0.25) {
          _trigger();
        }
      },
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.offset,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: duration,
          child: widget.child,
        ),
      ),
    );
  }
}

class _VenueDetailLoadingScreen extends StatefulWidget {
  const _VenueDetailLoadingScreen({
    required this.data,
    required this.apiBaseUrl,
  });

  final _VenueCardData data;
  final String apiBaseUrl;

  @override
  State<_VenueDetailLoadingScreen> createState() =>
      _VenueDetailLoadingScreenState();
}

class _VenueDetailLoadingScreenState extends State<_VenueDetailLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  late final AnimationController _haloController;

  @override
  void initState() {
    super.initState();
    _orbitController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _haloController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _navigateToDetail();
  }

  Future<void> _navigateToDetail() async {
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AuroraWarpRoute(
        _VenueDetailScreen(
          data: widget.data,
          apiBaseUrl: widget.apiBaseUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF030816), Color(0xFF0C1F3E), Color(0xFF1B2F6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _haloController,
              builder: (context, _) {
                final wave = math.sin(_haloController.value * 2 * math.pi);
                final swell = math.cos(_haloController.value * 2 * math.pi);
                return Stack(
                  children: [
                    _halo(
                      alignment: Alignment(-0.6 + wave * 0.2, -0.4 + swell * 0.15),
                      radius: 400 + wave * 60,
                      color: const Color(0x6648E0FF),
                    ),
                    _halo(
                      alignment: Alignment(0.7 + swell * 0.15, 0.5 + wave * 0.18),
                      radius: 480 + swell * 70,
                      color: const Color(0x449C4CFF),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _haloController,
              builder: (context, _) {
                final wave = math.sin(_haloController.value * 2 * math.pi);
                final sigma = 38 + wave * 18;
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma * 0.85,
                  ),
                  child: const SizedBox(),
                );
              },
            ),
          ),
          Center(child: _buildLoader()),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbitController, _pulseController]),
      builder: (context, child) {
        final orbit = _orbitController.value * 2 * math.pi;
        final pulse = 0.8 + _pulseController.value * 0.2;
        return Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            color: Colors.white.withValues(alpha: 0.05),
            boxShadow: [
              BoxShadow(
                color: const Color(0x993A8CFF).withValues(alpha: 0.4),
                blurRadius: 60,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90 * pulse,
                      height: 90 * pulse,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(0xFF3BE4FF),
                            Color(0xFF7F5CFF),
                            Color(0xFFFD8EFF),
                            Color(0xFF3BE4FF),
                          ],
                        ),
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      Transform.translate(
                        offset: Offset.fromDirection(
                          orbit + (math.pi / 2) * i,
                          42,
                        ),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Opening ${widget.data.name}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fetching availability and polishing details...',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _halo({
    required Alignment alignment,
    required double radius,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.01)],
          ),
        ),
      ),
    );
  }
}
class _DetailAuroraBackdrops extends StatelessWidget {
  const _DetailAuroraBackdrops({required this.phase});
  final double phase;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * 2 * math.pi);
    final swell = math.cos(phase * 2 * math.pi);
    return IgnorePointer(
      child: Stack(
        children: [
          _Halo(
            alignment: Alignment(-0.6 + wave * 0.1, -0.8 + swell * 0.05),
            size: 280 + swell * 30,
            colors: [const Color(0x5533478E), Colors.transparent],
            shadowColor: const Color(0x3333478E),
            blur: 160,
            spread: 12,
          ),
          _Halo(
            alignment: Alignment(0.7 + swell * 0.12, -0.6 + wave * 0.05),
            size: 240 + wave * 40,
            colors: [const Color(0x55304D8E), Colors.transparent],
            shadowColor: const Color(0x33304D8E),
            blur: 140,
            spread: 10,
          ),
          _Halo(
            alignment: Alignment(0.0 + wave * 0.12, 0.55 + swell * 0.08),
            size: 360 + wave * 50,
            colors: [const Color(0x553B5E9C), Colors.transparent],
            shadowColor: const Color(0x333B5E9C),
            blur: 200,
            spread: 14,
          ),
        ],
      ),
    );
  }
}

class _VenueDetailScreen extends StatelessWidget {
  const _VenueDetailScreen({
    required this.data,
    required this.apiBaseUrl,
  });

  final _VenueCardData data;
  final String apiBaseUrl;

  Future<void> _openBookingDialog(BuildContext context) async {
    final summary = await _showBookingDialog(context);
    if (summary == null || !context.mounted) return;
    await _showConfirmationDialog(context, summary);
  }

  Future<_BookingSummary?> _showBookingDialog(BuildContext context) {
    return showGeneralDialog<_BookingSummary>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'booking-dialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) => _DialogShell(
        child: _BookingDialog(
          pricePerSession: data.price,
          venueName: data.name,
          onSubmit: (start, end, phone) =>
              _submitBookingRequest(start, end, phone),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(curved),
            child: Transform.scale(
              scale: 0.92 + 0.08 * curved.value,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    _BookingSummary summary,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'booking-confirmation',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 620),
      pageBuilder: (_, __, ___) => _DialogShell(
        child: _BookingConfirmationCard(summary: summary),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
        );
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 70),
            child: Transform.rotate(
              angle: (1 - curved.value) * 0.18,
              child: Transform.scale(
                scale: 0.8 + 0.2 * curved.value,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_BookingSummary> _submitBookingRequest(
    DateTime start,
    DateTime end,
    String phone,
  ) async {
    final venueId = data.id;
    if (venueId == null) {
      return _BookingSummary.localMock(
        venueName: data.name,
        venuePrice: data.price,
        startDate: start,
        endDate: end,
        phoneNumber: phone,
      );
    }
    final uri = Uri.parse('$apiBaseUrl/api/bookings/');
    final username = Api.currentUsername;
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'venue_id': venueId,
        'start_date': start.toIso8601String().split('T').first,
        'end_date': end.toIso8601String().split('T').first,
        'phone_number': phone,
        'notes': 'Booking dibuat via aplikasi mobile',
        if (username != null && username.isNotEmpty) 'username': username,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = payload['detail']?.toString();
        throw Exception(detail ?? 'Gagal membuat booking');
      } catch (_) {
        throw Exception('Gagal membuat booking');
      }
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _BookingSummary.fromJson(decoded);
  }

  @override
  Widget build(BuildContext context) {
    final background = const Color(0xFF060C18);
    final highlight = const Color(0xFF12213D);
    final amenities = [
      'Locker rooms',
      'Premium lighting',
      'Cafe & lounge',
      'Free parking',
    ];
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          Positioned.fill(
            child: _DetailAuroraBackdrops(phase: 0.35),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: data.imageUrl.isNotEmpty
                                  ? Image.network(
                                      data.imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return const DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: _imageFallbackGradient,
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) =>
                                          const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: _imageFallbackGradient,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: _imageFallbackGradient,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).pushReplacement(
                                  AuroraWarpRoute(const HomeScreen()),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.category.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    data.location,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  data.rating.toStringAsFixed(1),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _GlassPanel(
                              overlayColor: highlight.withValues(alpha: 0.8),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mulai dari',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatPriceLabel(data.price),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    data.description,
                                    style: GoogleFonts.plusJakartaSans(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Fasilitas unggulan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: amenities
                                  .map(
                                    (amenity) => _DetailChip(text: amenity),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 32),
                            _DetailActionBar(
                              priceLabel: _formatPriceLabel(data.price),
                              onTapBook: () => _openBookingDialog(context),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.priceLabel,
    required this.onTapBook,
  });

  final String priceLabel;
  final VoidCallback onTapBook;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      overlayColor: const Color(0x33213A65),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Biaya per sesi',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceLabel,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  backgroundColor: const Color(0xFF1FA2FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: onTapBook,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: const Text('Pesan Jadwal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({
    required this.pricePerSession,
    required this.venueName,
    required this.onSubmit,
  });

  final int pricePerSession;
  final String venueName;
  final Future<_BookingSummary> Function(
    DateTime startDate,
    DateTime endDate,
    String phoneNumber,
  ) onSubmit;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now.add(const Duration(days: 1)));
    final firstDate = isStart ? now : (_startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1FA2FF),
              surface: Color(0xFF0B152C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _startCtrl.text = _formatReadableDate(picked);
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
          _endCtrl.text = _formatReadableDate(picked);
        }
      } else {
        _endDate = picked;
        _endCtrl.text = _formatReadableDate(picked);
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final phone = _phoneCtrl.text.trim();
    if (_startDate == null || _endDate == null || phone.isEmpty) {
      setState(
        () => _error = 'Mohon pilih tanggal mulai/selesai dan isi nomor telepon.',
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'Tanggal selesai tidak boleh sebelum tanggal mulai.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final summary = await widget.onSubmit(_startDate!, _endDate!, phone);
      if (!mounted) return;
      Navigator.of(context).pop(summary);
    } catch (err) {
      final message = err.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = message;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      overlayColor: Colors.white.withValues(alpha: 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Atur Jadwal',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatPriceLabel(widget.pricePerSession)} · ${widget.venueName}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 360;
              final startField = _DateField(
                label: 'Mulai',
                value: _startCtrl.text,
                hint: 'Pilih tanggal',
                onTap: () => _pickDate(isStart: true),
              );
              final endField = _DateField(
                label: 'Selesai',
                value: _endCtrl.text,
                hint: 'Pilih tanggal',
                onTap: () => _pickDate(isStart: false),
              );
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: startField),
                    const SizedBox(width: 16),
                    Expanded(child: endField),
                  ],
                );
              }
              return Column(
                children: [
                  startField,
                  const SizedBox(height: 16),
                  endField,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nomor telepon',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Contoh: 0812 3456 7890',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1FA2FF)),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFF8E8E),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF1FA2FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Booking...',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Book Now',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value.isEmpty ? hint : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    display,
                    style: GoogleFonts.plusJakartaSans(
                      color:
                          value.isEmpty ? Colors.white54 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingConfirmationCard extends StatelessWidget {
  const _BookingConfirmationCard({required this.summary});

  final _BookingSummary summary;

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${_formatReadableDate(summary.startDate)} \u2022 ${_formatReadableDate(summary.endDate)}';
    return _GlassPanel(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
      overlayColor: Colors.white.withValues(alpha: 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1FA2FF), Color(0xFF6B7CFF)],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            'Booking terkirim!',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll be contacted very soon.",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.venueName,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          _ConfirmationRow(
            label: 'ID Booking',
            value: '#${summary.id.toString().padLeft(4, '0')}',
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(label: 'Rentang tanggal', value: dateRange),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Total sesi',
            value: '${summary.sessions}x',
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Status',
            value: summary.hasBeenPaid ? 'Paid' : 'Menunggu konfirmasi',
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Subtotal',
            value: _formatCurrency(summary.subtotal),
            emphasize: true,
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Kontak',
            value: summary.phoneNumber,
          ),
          if ((summary.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _ConfirmationRow(
              label: 'Catatan',
              value: summary.notes!,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: const Color(0xFF1FA2FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Okay',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          )
        : GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: style,
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

class _BookingSummary {
  const _BookingSummary({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.venueType,
    required this.venueLocation,
    required this.venueDescription,
    required this.venueImageUrl,
    required this.venuePrice,
    required this.startDate,
    required this.endDate,
    required this.sessions,
    required this.subtotal,
    required this.phoneNumber,
    required this.hasBeenPaid,
    required this.datePaid,
    required this.createdAt,
    this.notes,
  });

  factory _BookingSummary.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? value) =>
        DateTime.tryParse(value ?? '') ?? DateTime.now();
    final venue = (json['venue'] as Map<String, dynamic>?) ?? const {};
    return _BookingSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      venueId: (venue['id'] as num?)?.toInt() ?? 0,
      venueName: (venue['title'] ?? 'Venue').toString(),
      venueType: (venue['type'] ?? '').toString(),
      venueLocation: (venue['location'] ?? '').toString(),
      venueDescription: (venue['description'] ?? '').toString(),
      venueImageUrl: (venue['image_url'] ?? '').toString(),
      venuePrice: (venue['price'] as num?)?.toInt() ?? 0,
      startDate: parseDate(json['start_date']?.toString()),
      endDate: parseDate(json['end_date']?.toString()),
      sessions: (json['sessions'] as num?)?.toInt() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      phoneNumber: (json['contact_phone'] ?? '').toString(),
      hasBeenPaid: json['has_been_paid'] == true,
      datePaid:
          json['date_paid'] == null ? null : parseDate(json['date_paid']?.toString()),
      createdAt: parseDate(json['created_at']?.toString()),
      notes: json['notes']?.toString(),
    );
  }

  factory _BookingSummary.localMock({
    required String venueName,
    required int venuePrice,
    required DateTime startDate,
    required DateTime endDate,
    required String phoneNumber,
  }) {
    final sessions = endDate.difference(startDate).inDays + 1;
    final now = DateTime.now();
    return _BookingSummary(
      id: now.millisecondsSinceEpoch,
      venueId: 0,
      venueName: venueName,
      venueType: 'Venue',
      venueLocation: 'Jakarta, Indonesia',
      venueDescription: 'Booking simulasi untuk $venueName.',
      venueImageUrl: '',
      venuePrice: venuePrice,
      startDate: startDate,
      endDate: endDate,
      sessions: sessions,
      subtotal: sessions * venuePrice,
      phoneNumber: phoneNumber,
      hasBeenPaid: false,
      datePaid: null,
      createdAt: now,
      notes: 'Booking demo tanpa backend',
    );
  }

  final int id;
  final int venueId;
  final String venueName;
  final String venueType;
  final String venueLocation;
  final String venueDescription;
  final String venueImageUrl;
  final int venuePrice;
  final DateTime startDate;
  final DateTime endDate;
  final int sessions;
  final int subtotal;
  final String phoneNumber;
  final bool hasBeenPaid;
  final DateTime? datePaid;
  final DateTime createdAt;
  final String? notes;
}

String _formatPriceLabel(int price) {
  if (price <= 0) return 'Check availability';
  return '${_formatCurrency(price)} / sesi';
}

String _formatCurrency(int value) {
  if (value <= 0) return 'Rp 0';
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final needsSeparator = i != 0 && (digits.length - i) % 3 == 0;
    if (needsSeparator) buffer.write('.');
    buffer.write(digits[i]);
  }
  return 'Rp ${buffer.toString()}';
}

String _formatReadableDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  return '$day $month ${date.year}';
}




