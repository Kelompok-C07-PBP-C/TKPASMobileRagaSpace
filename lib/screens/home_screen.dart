import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:marco/services/api.dart';
import 'package:marco/services/base_url_resolver.dart';
import 'package:marco/theme/aurora_palette.dart';
import 'package:marco/widgets/aurora_backdrop.dart';
import 'package:marco/widgets/aurora_route.dart';
import 'package:marco/widgets/twinkle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'account_settings_screen.dart';
import 'login_screen.dart';

part 'home_screen_models.dart';
part 'home_screen_catalog.dart';
part 'home_screen_wishlist.dart';
part 'home_screen_bookings.dart';
part 'home_screen_widgets.dart';

const _backgroundGradient = AuroraPalette.sky;
const _ctaBlue = Color(0xFF1FA2FF);
const _ctaTeal = Color(0xFF2CD5FF);
const _imageFallbackGradient = LinearGradient(
  colors: [Color(0xFF132548), Color(0xFF1E3C6B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _wishlistStorageBaseKey = 'wishlist_venues';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static final String _apiBaseUrl = resolveBaseApiHost();
  static final String _apiHostBase = _apiBaseUrl.replaceFirst(
    RegExp(r'/api/?$'),
    '',
  );
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
          'Cari lapangan sepak bola, futsal, basket, atau badminton favoritmu, pilih jadwal kosong, lalu konfirmasi pembayaran dalam hitungan detik.',
      bullets: [
        'Filter tipe olahraga, kota, harga, dan tipe permukaan rumput.',
        'Lihat slot realtime untuk sesi latihan, sparring, atau turnamen.',
        'Checkout aman—invoice otomatis dikirim ke tim dan pengelola.',
      ],
      gradient: [Color(0xFF4F46E5), Color(0xFF9337FF)],
      icon: Icons.flash_on_rounded,
    ),
    _PromoCardData(
      title: 'Raih Jam Latihan Terbaik',
      description:
          'Cari slot murah, atur jadwal tim, dan manfaatkan promo komunitas langsung dari aplikasi tanpa harus menghubungi admin venue.',
      bullets: [
        'Aktifkan notifikasi supaya dapat info slot kosong & promo flash.',
        'Pantau jadwal rutin tim dan langsung ajak pemain cadangan.',
        'Booking bareng komunitas lain untuk bagi biaya lapangan.',
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
  String _resolveWishlistStorageKey() {
    final userId = Api.currentUserId;
    if (userId != null) return '$_wishlistStorageBaseKey:$userId';
    return '$_wishlistStorageBaseKey:guest';
  }

  String? _avatarUrl;
  String? _accountPhoneNumber;
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
  late final PageController _highlightController;
  Timer? _highlightTimer;
  Timer? _testimonialTimer;
  late final ScrollController _scrollController;
  int _navIndex = 0;
  int _testimonialPage = 0;
  bool _stickyNavVisible = false;
  bool _highlightAutoplayEnabled = true;
  final UniqueKey _highlightVisibilityKey = UniqueKey();
  bool _testimonialAutoplayEnabled = true;
  final UniqueKey _testimonialVisibilityKey = UniqueKey();
  late final AnimationController _categoryMarqueeController;
  @override
  void initState() {
    super.initState();
    _highlightController = PageController(viewportFraction: 0.9);
    _categoryMarqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _startHighlightAutoScroll();
    _startTestimonialAutoScroll();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _fetchTopVenues();
    _loadWishlist();
    _loadProfileSummary();
  }

  void _startHighlightAutoScroll() {
    _highlightTimer?.cancel();
    if (_highlightPageCount <= 1) {
      _highlightAutoplayEnabled = false;
      return;
    }
    _highlightAutoplayEnabled = true;
    _highlightTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_highlightController.hasClients) return;
      final current =
          _highlightController.page?.round() ??
          _highlightController.initialPage;
      final next = (current + 1) % _highlightPageCount;
      _highlightController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _pauseHighlightAutoScroll() {
    if (!_highlightAutoplayEnabled) return;
    _highlightAutoplayEnabled = false;
    _highlightTimer?.cancel();
    _highlightTimer = null;
  }

  void _startTestimonialAutoScroll() {
    _testimonialTimer?.cancel();
    if (_testimonials.length <= 1) {
      _testimonialAutoplayEnabled = false;
      return;
    }
    _testimonialAutoplayEnabled = true;
    _testimonialTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      final next = (_testimonialPage + 1) % _testimonials.length;
      setState(() => _testimonialPage = next);
    });
  }

  void _pauseTestimonialAutoScroll() {
    if (!_testimonialAutoplayEnabled) return;
    _testimonialAutoplayEnabled = false;
    _testimonialTimer?.cancel();
    _testimonialTimer = null;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 120;
    if (shouldShow != _stickyNavVisible) {
      setState(() => _stickyNavVisible = shouldShow);
    }
  }

  int get _highlightPageCount => _highlightCards.length + 1;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _testimonialTimer?.cancel();
    _highlightController.dispose();
    _categoryMarqueeController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.22)),
          const Positioned.fill(child: _StaticAuroraBackdrop()),
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
              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
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
              alignment: singleColumn
                  ? WrapAlignment.center
                  : WrapAlignment.start,
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
                final double horizontalPadding = constraints.maxWidth < 240
                    ? 20
                    : 32;
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
        return VisibilityDetector(
          key: _testimonialVisibilityKey,
          onVisibilityChanged: (info) {
            final shouldRun = info.visibleFraction > 0.3;
            if (shouldRun && !_testimonialAutoplayEnabled) {
              _startTestimonialAutoScroll();
            } else if (!shouldRun && _testimonialAutoplayEnabled) {
              _pauseTestimonialAutoScroll();
            }
          },
          child: Column(
            children: [
              SizedBox(
                height: cardHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Padding(
                    key: ValueKey('${_testimonialPage}_$stacked'),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _TestimonialCard(
                      data: _testimonials[_testimonialPage],
                      stacked: stacked,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildTestimonialControls(),
            ],
          ),
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    setState(() => _testimonialPage = next);
  }

  void _previousTestimonial() {
    final prev = _testimonialPage == 0
        ? _testimonials.length - 1
        : _testimonialPage - 1;
    setState(() => _testimonialPage = prev);
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
          initialWishlistKeys: Set<String>.from(_wishlistKeys),
          onToggleFavorite: _toggleWishlistAndReturn,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
    if (selected != null) _openCatalogVenue(selected);
  }

  Future<void> _openWishlist() async {
    if (_navIndex == 2) return;
    await _syncWishlistFromServer(localSeed: _wishlist, silent: true);
    if (!mounted) return;
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
    try {
      await Api().logout();
    } catch (_) {
      // ignore network errors, still navigate to login
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
      final uri = Uri.parse('$_apiBaseUrl/api/venues/top/?limit=3');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
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
    final seed = await _restoreWishlistFromStorage();
    if (!mounted) return;
    unawaited(_syncWishlistFromServer(localSeed: seed));
  }

  Future<List<_VenueCardData>> _restoreWishlistFromStorage() async {
    _prefs ??= await SharedPreferences.getInstance();
    final storageKey = _resolveWishlistStorageKey();
    final stored = _prefs!.getStringList(storageKey) ?? [];
    final parsed = <_VenueCardData>[];
    var needsPersist = false;
    for (final item in stored) {
      try {
        parsed.add(_VenueCardData.fromMap(jsonDecode(item)));
      } catch (_) {
        needsPersist = true;
      }
    }
    var cleaned = parsed.where((item) => item.id != null).toList();
    needsPersist = needsPersist || cleaned.length != parsed.length;
    try {
      final existingIds = await _fetchAllVenueIds();
      if (existingIds != null && existingIds.isNotEmpty) {
        final filtered = cleaned
            .where((item) => item.id != null && existingIds.contains(item.id))
            .toList();
        if (filtered.length != cleaned.length) {
          cleaned = filtered;
          needsPersist = true;
        }
      }
    } catch (_) {
      // ignore network errors; fallback to currently known items
    }
    if (needsPersist) {
      final encoded = cleaned.map((e) => jsonEncode(e.toMap())).toList();
      await _prefs!.setStringList(storageKey, encoded);
    }
    if (mounted) {
      setState(() {
        _wishlist = cleaned;
        _wishlistKeys = cleaned.map((e) => e.storageKey).toSet();
      });
    }
    return cleaned;
  }

  Future<void> _loadProfileSummary() async {
    final userId = Api.currentUserId;
    if (userId == null) return;
    try {
      final data = await Api().fetchAccount(userId);
      final avatar = (data['avatar_url'] ?? '').toString();
      final phone = (data['phone_number'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _avatarUrl = avatar;
        _accountPhoneNumber = phone;
      });
    } catch (_) {
      // ignore failure; keep placeholder avatar
    }
  }

  Future<Set<int>?> _fetchAllVenueIds() async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/venues/');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final payload = jsonDecode(res.body) as List<dynamic>;
      final ids = <int>{};
      for (final raw in payload) {
        final map = raw as Map<String, dynamic>;
        final idValue = map['id'];
        final parsed = idValue is int ? idValue : int.tryParse('$idValue');
        if (parsed != null) ids.add(parsed);
      }
      return ids;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistWishlist() async {
    _prefs ??= await SharedPreferences.getInstance();
    final storageKey = _resolveWishlistStorageKey();
    final seen = <String>{};
    final encoded = <String>[];
    for (final item in _wishlist) {
      final key = item.storageKey;
      if (seen.add(key)) {
        encoded.add(jsonEncode(item.toMap()));
      }
    }
    await _prefs!.setStringList(storageKey, encoded);
  }

  Future<void> _syncWishlistFromServer({
    List<_VenueCardData>? localSeed,
    bool silent = true,
  }) async {
    final userId = Api.currentUserId;
    if (userId == null) return;
    try {
      final api = Api();
      final payloads = await api.fetchWishlist(userId: userId);
      final syncedItems = <_VenueCardData>[];
      final syncedKeys = <String>{};
      for (final entry in payloads) {
        try {
          final data = _VenueCardData.fromWishlistPayload(entry);
          final key = data.storageKey;
          if (key.isEmpty || syncedKeys.contains(key)) continue;
          syncedItems.add(data);
          syncedKeys.add(key);
        } catch (_) {
          continue;
        }
      }
      final seed = List<_VenueCardData>.from(localSeed ?? _wishlist);
      for (final item in seed) {
        if (item.id == null) continue;
        final key = item.storageKey;
        if (syncedKeys.contains(key)) continue;
        try {
          final fresh = await api.addWishlistItem(
            userId: userId,
            venueId: item.id!,
          );
          final syncedData = _VenueCardData.fromWishlistPayload(fresh);
          final syncedKey = syncedData.storageKey;
          if (syncedKey.isNotEmpty && !syncedKeys.contains(syncedKey)) {
            syncedItems.add(syncedData);
            syncedKeys.add(syncedKey);
          }
        } catch (_) {
          // ignore failed uploads; they'll retry on next sync
        }
      }
      if (!mounted) return;
      setState(() {
        _wishlist = syncedItems;
        _wishlistKeys = syncedKeys;
      });
      await _persistWishlist();
    } catch (err) {
      if (!silent && mounted) {
        _showWishlistError(err);
      }
    }
  }

  Future<void> _toggleWishlist(_VenueCardData data) async {
    final key = data.storageKey;
    final adding = !_wishlistKeys.contains(key);
    final previousList = List<_VenueCardData>.from(_wishlist);
    final previousKeys = Set<String>.from(_wishlistKeys);
    setState(() {
      _wishlist.removeWhere((item) => item.storageKey == key);
      if (adding) {
        _wishlist.add(data);
        _wishlistKeys.add(key);
      } else {
        _wishlistKeys.remove(key);
      }
    });
    try {
      final userId = Api.currentUserId;
      if (userId != null && data.id != null) {
        if (adding) {
          final payload = await Api().addWishlistItem(
            userId: userId,
            venueId: data.id!,
          );
          final synced = _VenueCardData.fromWishlistPayload(payload);
          if (mounted) {
            setState(() {
              _wishlist.removeWhere((item) => item.storageKey == key);
              _wishlist.add(synced);
              _wishlistKeys.add(key);
            });
          }
        } else {
          await Api().removeWishlistItem(userId: userId, venueId: data.id!);
        }
      }
      await _persistWishlist();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _wishlist = previousList;
        _wishlistKeys = previousKeys;
      });
      _showWishlistError(err);
    }
  }

  Future<bool> _toggleWishlistAndReturn(_VenueCardData data) async {
    await _toggleWishlist(data);
    return _wishlistKeys.contains(data.storageKey);
  }

  void _showWishlistError(Object error) {
    if (!mounted) return;
    final message = error is ApiError
        ? error.message
        : 'Gagal memperbarui wishlist. Coba lagi.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            final itemWidth = isWide
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    this.useGradient = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color overlayColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: useGradient ? AuroraPalette.glassGradient(overlayColor) : null,
      color: useGradient ? null : overlayColor,
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.12),
      ),
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 20),
            ),
          ],
    );
    return Container(padding: padding, decoration: decoration, child: child);
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
  const _CategoryChip({required this.data, this.width});
  final _CategoryChipData data;
  final double? width;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: _categoryChipTextStyle(),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _categoryChipTextStyle() => GoogleFonts.plusJakartaSans(
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

double _calculateChipWidth(String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: _categoryChipTextStyle()),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  const double horizontalPadding = 18 * 2;
  const double iconWidth = 18;
  const double iconGap = 8;
  return painter.width + horizontalPadding + iconWidth + iconGap;
}

enum _AuroraBackdropStyle { standard, detail }

class _StaticAuroraBackdrop extends StatelessWidget {
  const _StaticAuroraBackdrop({this.style = _AuroraBackdropStyle.standard});

  final _AuroraBackdropStyle style;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _StaticAuroraPainter(style)),
      ),
    );
  }
}

class _StaticAuroraPainter extends CustomPainter {
  const _StaticAuroraPainter(this.style);

  final _AuroraBackdropStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final ribbons = _buildRibbons(style);
    for (final ribbon in ribbons) {
      _paintRibbon(canvas, size, ribbon);
    }
    _paintStarfield(canvas, size);
    _paintHorizonGlow(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _StaticAuroraPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}

class _AuroraRibbon {
  const _AuroraRibbon({
    required this.start,
    required this.end,
    required this.control1,
    required this.control2,
    required this.thickness,
    required this.colors,
    this.blur = 90,
  });

  final Offset start;
  final Offset end;
  final Offset control1;
  final Offset control2;
  final double thickness;
  final List<Color> colors;
  final double blur;
}

List<_AuroraRibbon> _buildRibbons(_AuroraBackdropStyle style) {
  final bright = style == _AuroraBackdropStyle.detail
      ? const [Color(0xFF5EECFF), Color(0x8826FFC8)]
      : const [Color(0xFF60F3FF), Color(0x6624FFD5)];
  final mid = style == _AuroraBackdropStyle.detail
      ? const [Color(0xFF3BC3FF), Color(0x5523A8FF)]
      : const [Color(0xFF40C5FF), Color(0x553497FF)];
  final soft = style == _AuroraBackdropStyle.detail
      ? const [Color(0xFF2DF1C1), Color(0x3324A0FF)]
      : const [Color(0xFF2DF1C1), Color(0x332486FF)];
  return [
    _AuroraRibbon(
      start: const Offset(-0.1, 0.2),
      end: const Offset(0.35, 0.95),
      control1: const Offset(0.1, 0.1),
      control2: const Offset(0.15, 0.65),
      thickness: 0.09,
      colors: bright,
    ),
    _AuroraRibbon(
      start: const Offset(0.1, 0.05),
      end: const Offset(0.7, 0.9),
      control1: const Offset(0.25, 0.0),
      control2: const Offset(0.5, 0.7),
      thickness: 0.08,
      colors: mid,
      blur: 110,
    ),
    _AuroraRibbon(
      start: const Offset(0.6, 0.08),
      end: const Offset(1.05, 0.85),
      control1: const Offset(0.75, 0.12),
      control2: const Offset(0.9, 0.65),
      thickness: 0.07,
      colors: soft,
    ),
  ];
}

void _paintRibbon(Canvas canvas, Size size, _AuroraRibbon ribbon) {
  final start = Offset(
    ribbon.start.dx * size.width,
    ribbon.start.dy.clamp(0.0, 1.0) * size.height,
  );
  final end = Offset(
    ribbon.end.dx * size.width,
    ribbon.end.dy.clamp(0.0, 1.0) * size.height,
  );
  final c1 = Offset(
    ribbon.control1.dx * size.width,
    ribbon.control1.dy.clamp(0.0, 1.0) * size.height,
  );
  final c2 = Offset(
    ribbon.control2.dx * size.width,
    ribbon.control2.dy.clamp(0.0, 1.0) * size.height,
  );
  final thickness = ribbon.thickness * size.width;
  final path = Path()
    ..moveTo(start.dx - thickness, start.dy)
    ..cubicTo(
      c1.dx - thickness * 0.6,
      c1.dy,
      c2.dx - thickness * 0.4,
      c2.dy,
      end.dx - thickness * 0.2,
      end.dy,
    )
    ..lineTo(end.dx + thickness, end.dy)
    ..cubicTo(
      c2.dx + thickness * 0.4,
      c2.dy,
      c1.dx + thickness * 0.6,
      c1.dy,
      start.dx + thickness,
      start.dy,
    )
    ..close();

  final shader = LinearGradient(
    colors: ribbon.colors,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromPoints(start, end));

  final paint = Paint()
    ..shader = shader
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, ribbon.blur);
  canvas.drawPath(path, paint);
}

void _paintStarfield(Canvas canvas, Size size) {
  final starPaint = Paint()..style = PaintingStyle.fill;
  final stars = <Offset>[
    const Offset(0.1, 0.12),
    const Offset(0.18, 0.28),
    const Offset(0.32, 0.08),
    const Offset(0.48, 0.2),
    const Offset(0.58, 0.05),
    const Offset(0.7, 0.18),
    const Offset(0.82, 0.12),
    const Offset(0.9, 0.3),
  ];
  for (var i = 0; i < stars.length; i++) {
    final star = stars[i];
    final radius = size.shortestSide * (0.002 + (i % 3) * 0.001);
    starPaint.color = Colors.white.withValues(alpha: 0.15 + (i % 3) * 0.1);
    canvas.drawCircle(
      Offset(star.dx * size.width, star.dy * size.height),
      radius,
      starPaint,
    );
  }
}

void _paintHorizonGlow(Canvas canvas, Size size) {
  final rect = Rect.fromLTWH(0, size.height * 0.4, size.width, size.height);
  final gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: const [
      Color(0x002AF0FF),
      Color(0x1429E7FF),
      Color(0x2625B4FF),
      Color(0x0F0B1C30),
      Color(0x00010208),
    ],
    stops: const [0.0, 0.35, 0.65, 0.85, 1.0],
  );
  final paint = Paint()..shader = gradient.createShader(rect);
  canvas.drawRect(rect, paint);
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
    required this.isFavorite,
    required this.onToggleFavorite,
    this.accountPhoneNumber,
  });

  final _VenueCardData data;
  final String apiBaseUrl;
  final bool isFavorite;
  final String? accountPhoneNumber;
  final Future<bool> Function(_VenueCardData data) onToggleFavorite;

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
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
          isFavorite: widget.isFavorite,
          accountPhoneNumber: widget.accountPhoneNumber,
          onToggleFavorite: widget.onToggleFavorite,
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
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AuroraPalette.sky),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.2)),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _haloController,
              builder: (context, _) {
                return AuroraBackdrop(
                  phase: _haloController.value,
                  variant: AuroraBackdropVariant.dense,
                  opacity: 0.85,
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            gradient: const LinearGradient(
              colors: [Color(0x66132F55), Color(0x33305B7D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2FB5FF).withValues(alpha: 0.35),
                blurRadius: 65,
                spreadRadius: 8,
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
}

class _CategoryMarqueeRow extends StatelessWidget {
  const _CategoryMarqueeRow({
    required this.data,
    required this.animation,
    this.phase = 0,
    this.reverse = false,
  });

  final List<_CategoryChipData> data;
  final Animation<double> animation;
  final double phase;
  final bool reverse;

  static const double _spacing = 10;

  @override
  Widget build(BuildContext context) {
    final widths = data
        .map((category) => _calculateChipWidth(category.label))
        .toList();
    if (data.length <= 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            _CategoryChip(data: data[i], width: widths[i]),
            if (i != data.length - 1) const SizedBox(width: _spacing),
          ],
        ],
      );
    }
    final baseWidth =
        widths.fold<double>(0, (sum, width) => sum + width) +
        (data.length - 1) * _spacing;
    if (baseWidth <= 0) return const SizedBox();

    final sequence = _buildSequence(widths);
    final travel = baseWidth + _spacing;
    final tape = SizedBox(
      width: travel * 2,
      child: Row(
        children: [
          ...sequence,
          const SizedBox(width: _spacing),
          ...sequence,
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : baseWidth;
        return SizedBox(
          width: viewportWidth,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final progress = ((animation.value + phase) % 1.0);
                final shift = progress * travel;
                final dx = reverse ? shift - travel : -shift;
                return Transform.translate(offset: Offset(dx, 0), child: tape);
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSequence(List<double> widths) {
    final children = <Widget>[];
    for (var i = 0; i < data.length; i++) {
      children.add(_CategoryChip(data: data[i], width: widths[i]));
      if (i != data.length - 1) {
        children.add(const SizedBox(width: _spacing));
      }
    }
    return children;
  }
}

class _VenueDetailScreen extends StatefulWidget {
  const _VenueDetailScreen({
    required this.data,
    required this.apiBaseUrl,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.accountPhoneNumber,
  });

  final _VenueCardData data;
  final String apiBaseUrl;
  final bool isFavorite;
  final String? accountPhoneNumber;
  final Future<bool> Function(_VenueCardData data) onToggleFavorite;

  @override
  State<_VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<_VenueDetailScreen> {
  late _VenueCardData data;
  late String apiBaseUrl;
  late bool _isFavorite;
  List<_VenueReview> _reviews = const [];
  String? _accountPhoneNumber;
  bool _loadingReviews = false;
  String? _reviewsError;
  bool _submittingReview = false;
  bool _availabilityLoaded = false;
  bool _availabilityLoading = false;
  Completer<void>? _availabilityCompleter;
  Set<int> _blockedDayKeyCache = <int>{};
  List<_BookedDateRange> _bookedRanges = const [];
  Map<int, List<_DailyHourRange>> _bookedHoursByDay = const {};
  final Set<int> _detailSelectedAddonIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    data = widget.data;
    apiBaseUrl = widget.apiBaseUrl;
    _isFavorite = widget.isFavorite;
    _accountPhoneNumber = widget.accountPhoneNumber;
    _loadBookedRanges();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReviews();
    });
  }

  Future<void> _toggleFavorite() async {
    final result = await widget.onToggleFavorite(data);
    if (!mounted) return;
    setState(() => _isFavorite = result);
  }

  void _openAccountSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()))
        .then((_) => _refreshAccountPhone());
  }

  Future<void> _refreshAccountPhone() async {
    final userId = Api.currentUserId;
    if (userId == null) return;
    try {
      final data = await Api().fetchAccount(userId);
      final phone = (data['phone_number'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _accountPhoneNumber = phone;
      });
    } catch (_) {
      // ignore refresh errors
    }
  }

  void _toggleDetailAddonSelection(int index, bool isSelected) {
    if (index < 0 || index >= data.addons.length) {
      return;
    }
    setState(() {
      if (isSelected) {
        _detailSelectedAddonIndexes.add(index);
      } else {
        _detailSelectedAddonIndexes.remove(index);
      }
    });
  }

  int get _detailSelectedAddonsTotal {
    if (data.addons.isEmpty || _detailSelectedAddonIndexes.isEmpty) return 0;
    return _detailSelectedAddonIndexes.fold<int>(0, (sum, index) {
      if (index < 0 || index >= data.addons.length) return sum;
      return sum + data.addons[index].price;
    });
  }

  Map<int, List<_DailyHourRange>> _buildBookedHoursByDay(
    List<_BookedDateRange> ranges,
  ) {
    final result = <int, List<_DailyHourRange>>{};
    for (final range in ranges) {
      var dayCursor =
          DateTime(range.start.year, range.start.month, range.start.day);
      while (dayCursor.isBefore(range.end)) {
        final dayStart = dayCursor;
        final dayEnd = dayStart.add(const Duration(days: 1));
        final segmentStart =
            range.start.isAfter(dayStart) ? range.start : dayStart;
        final segmentEnd = range.end.isBefore(dayEnd) ? range.end : dayEnd;
        if (segmentEnd.isAfter(segmentStart)) {
          final dayKey = _dayKeyFromDate(dayStart);
          final startHour =
              segmentStart.difference(dayStart).inMinutes / 60.0;
          final endHour = segmentEnd.difference(dayStart).inMinutes / 60.0;
          result
              .putIfAbsent(dayKey, () => <_DailyHourRange>[])
              .add(_DailyHourRange(startHour: startHour, endHour: endHour));
        }
        dayCursor = dayEnd;
      }
    }
    for (final entry in result.entries) {
      entry.value.sort((a, b) => a.startHour.compareTo(b.startHour));
    }
    return result;
  }

  Set<int> _computeBlockedDayKeys(
    Map<int, List<_DailyHourRange>> hourMap,
  ) {
    final blocked = <int>{};
    hourMap.forEach((dayKey, ranges) {
      if (_isDayFullyBooked(ranges)) {
        blocked.add(dayKey);
      }
    });
    return blocked;
  }

  bool _isDayFullyBooked(List<_DailyHourRange> ranges) {
    if (ranges.isEmpty) return false;
    double coverage = 0;
    for (final range in ranges) {
      if (range.startHour > coverage) {
        return false;
      }
      coverage = math.max(coverage, range.endHour);
      if (coverage >= 24) {
        return true;
      }
    }
    return coverage >= 24;
  }

  void _applyBookedRanges(List<_BookedDateRange> ranges,
      {bool markLoaded = false}) {
    final hourMap = _buildBookedHoursByDay(ranges);
    final blockedKeys = _computeBlockedDayKeys(hourMap);
    if (mounted) {
      setState(() {
        _bookedRanges = ranges;
        _bookedHoursByDay = hourMap;
        _blockedDayKeyCache = blockedKeys;
        if (markLoaded) {
          _availabilityLoaded = true;
        }
      });
    } else {
      _bookedRanges = ranges;
      _bookedHoursByDay = hourMap;
      _blockedDayKeyCache = blockedKeys;
      if (markLoaded) {
        _availabilityLoaded = true;
      }
    }
  }

  List<_VenueAddon> get _detailSelectedAddons {
    if (data.addons.isEmpty || _detailSelectedAddonIndexes.isEmpty) {
      return const [];
    }
    return _detailSelectedAddonIndexes
        .where((index) => index >= 0 && index < data.addons.length)
        .map((index) => data.addons[index])
        .toList();
  }

  Future<void> _loadBookedRanges() async {
    if (_availabilityLoaded) return;
    if (_availabilityLoading) {
      await _availabilityCompleter?.future;
      return;
    }
    final venueId = data.id;
    if (venueId == null) return;
    _availabilityLoading = true;
    final completer = Completer<void>();
    _availabilityCompleter = completer;
    var success = false;
    try {
      final uri = Uri.parse('$apiBaseUrl/api/venues/$venueId/availability/');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded['data']
          : decoded;
      final ranges = <_BookedDateRange>[];
      if (payload is List) {
        for (final item in payload) {
          if (item is Map<String, dynamic>) {
            final range = _BookedDateRange.tryParse(item);
            if (range != null) ranges.add(range);
          }
        }
      }
      _applyBookedRanges(ranges);
      success = true;
    } catch (_) {
      // ignore errors; booking dialog will rely on backend validation
    } finally {
      _availabilityLoading = false;
      _availabilityCompleter = null;
      _availabilityLoaded = success;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _openBookingDialog(BuildContext context) async {
    final phone = (_accountPhoneNumber ?? '').trim();
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tambahkan nomor telepon di Account settings sebelum booking.'),
          ),
        );
      }
      _openAccountSettings();
      return;
    }
    await _loadBookedRanges();
    if (!context.mounted) return;
    final summary = await _showBookingDialog(context);
    if (summary == null || !context.mounted) return;
    _appendBookedRange(summary.startDate, summary.endDate);
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
          disabledDayKeys: _blockedDayKeys(),
          selectedAddons: _detailSelectedAddons,
          bookedRanges: _bookedRanges,
          bookedHoursByDay: _bookedHoursByDay,
          phoneNumber: (_accountPhoneNumber ?? '').trim(),
          onSubmit: (start, end, phone, addons) =>
              _submitBookingRequest(start, end, phone, addons),
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

  Set<int> _blockedDayKeys() => _blockedDayKeyCache;

  void _appendBookedRange(DateTime start, DateTime end) {
    var normalizedStart = start;
    var normalizedEnd = end;
    if (normalizedEnd.isBefore(normalizedStart)) {
      final temp = normalizedStart;
      normalizedStart = normalizedEnd;
      normalizedEnd = temp;
    }
    final updatedRanges = [
      ..._bookedRanges,
      _BookedDateRange(start: normalizedStart, end: normalizedEnd),
    ];
    _applyBookedRanges(updatedRanges, markLoaded: true);
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
      pageBuilder: (_, __, ___) =>
          _DialogShell(child: _BookingConfirmationCard(summary: summary)),
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
    List<_VenueAddon> selectedAddons,
  ) async {
    final venueId = data.id;
    if (venueId == null) {
      return _BookingSummary.localMock(
        venueName: data.name,
        venuePrice: data.price,
        startDate: start,
        endDate: end,
        phoneNumber: phone,
        selectedAddons: selectedAddons,
      );
    }
    final uri = Uri.parse('$apiBaseUrl/api/bookings/');
    final username = Api.currentUsername;
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'venue_id': venueId,
        'start_date': start.toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
        'phone_number': phone,
        'notes': 'Booking dibuat via aplikasi mobile',
        if (selectedAddons.isNotEmpty)
          'selected_addons': selectedAddons
              .map((addon) => addon.toMap())
              .toList(),
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
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.18)),
          const Positioned.fill(
            child: _StaticAuroraBackdrop(style: _AuroraBackdropStyle.detail),
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
                                                gradient:
                                                    _imageFallbackGradient,
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
                                                Icons
                                                    .image_not_supported_outlined,
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
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pushReplacement(
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
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 16,
                                ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
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
                                  .map((amenity) => _DetailChip(text: amenity))
                                  .toList(),
                            ),
                            const SizedBox(height: 32),
                            if (data.addons.isNotEmpty) ...[
                              _AddonSelectionPanel(
                                addons: data.addons,
                                selectedIndexes: _detailSelectedAddonIndexes,
                                onToggle: _toggleDetailAddonSelection,
                              ),
                              const SizedBox(height: 28),
                            ],
                            _DetailActionBar(
                              pricePerSession: data.price,
                              onTapBook: () => _openBookingDialog(context),
                            ),
                            const SizedBox(height: 40),
                            _buildReviewsSection(),
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
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: _FavoriteBadgeButton(
                  isFavorite: _isFavorite,
                  onTap: () {
                    _toggleFavorite();
                    Feedback.forTap(context);
                  },
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReviewComposer({_VenueReview? review}) async {
    final result = await _showReviewDialog(existing: review);
    if (result == null || data.id == null) return;
    setState(() => _submittingReview = true);
    try {
      final uri = review == null
          ? Uri.parse('$apiBaseUrl/api/venues/${data.id}/reviews/')
          : Uri.parse(
              '$apiBaseUrl/api/venues/${data.id}/reviews/${review.id}/',
            );
      final body = <String, dynamic>{
        'rating': result.rating,
        'comment': result.comment,
      };
      final userId = Api.currentUserId;
      final username = Api.currentUsername;
      if (userId != null) body['user_id'] = userId;
      if (username != null && username.isNotEmpty) body['username'] = username;
      final response = review == null
          ? await http
                .post(
                  uri,
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 8))
          : await http
                .put(
                  uri,
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 8));
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        await _fetchReviews();
      } else {
        throw Exception('Failed');
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa menyimpan ulasan: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingReview = false);
      }
    }
  }

  Future<void> _deleteReview(_VenueReview review) async {
    if (data.id == null) return;
    final confirmed = await _confirmDeleteReview(review: review);
    if (!confirmed) return;
    try {
      var uri = Uri.parse(
        '$apiBaseUrl/api/venues/${data.id}/reviews/${review.id}/',
      );
      final userId = Api.currentUserId;
      if (userId != null) {
        uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'user_id': '$userId'},
        );
      }
      final res = await http.delete(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          _reviews = _reviews.where((r) => r.id != review.id).toList();
        });
      } else {
        throw Exception('Failed');
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa menghapus ulasan: $err')),
      );
    }
  }

  Future<bool> _confirmDeleteReview({_VenueReview? review}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B152C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          review == null ? 'Hapus ulasan?' : 'Hapus ulasan ${review.author}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<_ReviewDraft?> _showReviewDialog({_VenueReview? existing}) {
    final controller = TextEditingController(text: existing?.comment ?? '');
    int rating = existing?.rating ?? 5;
    return showDialog<_ReviewDraft>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B152C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          existing == null ? 'Tulis ulasan' : 'Edit ulasan',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rating', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  _buildStarSelector(
                    currentRating: rating,
                    onChanged: (value) => setState(() => rating = value),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Komentar',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(
                ctx,
              ).pop(_ReviewDraft(rating: rating, comment: text));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FA2FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildStarSelector({
    required int currentRating,
    required ValueChanged<int> onChanged,
    double size = 30,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final active = index < currentRating;
        return IconButton(
          iconSize: size,
          padding: EdgeInsets.zero,
          onPressed: () => onChanged(index + 1),
          icon: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            color: active ? Colors.amber : Colors.white24,
          ),
        );
      }),
    );
  }

  Widget _buildReviewsSection() {
    final canReview = Api.currentUserId != null;
    final venueId = data.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ulasan Pengguna',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: (!canReview || venueId == null || _submittingReview)
                  ? null
                  : () => _openReviewComposer(),
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Tulis ulasan'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (_reviewsError != null)
          Text(
            _reviewsError!,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          )
        else if (_reviews.isEmpty)
          Text(
            'Belum ada ulasan untuk venue ini.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          )
        else
          Column(
            children: _reviews
                .map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ReviewCard(
                      review: review,
                      onEdit: review.isMine
                          ? () => _openReviewComposer(review: review)
                          : null,
                      onDelete: review.isMine
                          ? () => _deleteReview(review)
                          : null,
                      starBuilder: _buildStarRow,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildStarRow(int rating, {double size = 18}) {
    return Row(
      children: List.generate(5, (index) {
        final active = index < rating;
        return Icon(
          active ? Icons.star_rounded : Icons.star_border_rounded,
          color: active ? Colors.amber : Colors.white24,
          size: size,
        );
      }),
    );
  }

  Future<void> _fetchReviews() async {
    final venueId = data.id;
    if (venueId == null) return;
    setState(() {
      _loadingReviews = true;
      _reviewsError = null;
    });
    try {
      final uri = Uri.parse('$apiBaseUrl/api/venues/$venueId/reviews/');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('Failed to load reviews');
      }
      final payload = jsonDecode(res.body) as List<dynamic>;
      final username = Api.currentUsername;
      final userId = Api.currentUserId;
      final parsed = payload
          .map(
            (raw) => _VenueReview.fromMap(
              raw as Map<String, dynamic>,
              currentUsername: username,
              currentUserId: userId,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _reviews = parsed;
        _loadingReviews = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _reviewsError = 'Tidak bisa memuat ulasan saat ini.';
        _loadingReviews = false;
      });
    }
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
        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.starBuilder,
    this.onEdit,
    this.onDelete,
  });

  final _VenueReview review;
  final Widget Function(int rating, {double size}) starBuilder;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      overlayColor: Colors.white.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatReadableDate(review.date),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 6),
          starBuilder(review.rating, size: 18),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft({required this.rating, required this.comment});
  final int rating;
  final String comment;
}

String _resolveMediaUrlGlobal(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final normalized = url.startsWith('/') ? url : '/$url';
  return '${_HomeScreenState._apiHostBase}$normalized';
}

class _AddonInfoCard extends StatelessWidget {
  const _AddonInfoCard({required this.addon});

  final _VenueAddon addon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  addon.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatCurrency(addon.price),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8AE8FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (addon.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              addon.description,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddonSelectionPanel extends StatelessWidget {
  const _AddonSelectionPanel({
    required this.addons,
    required this.selectedIndexes,
    required this.onToggle,
  });

  final List<_VenueAddon> addons;
  final Set<int> selectedIndexes;
  final void Function(int index, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (addons.isEmpty) {
      return const SizedBox.shrink();
    }
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 24,
      overlayColor: const Color(0x22102745),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tambah add-ons ke pesananmu',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...addons.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final addon = entry.value;
              final isSelected = selectedIndexes.contains(index);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == addons.length - 1 ? 0 : 12,
                ),
                child: _AddonCheckboxTile(
                  addon: addon,
                  selected: isSelected,
                  onChanged: (value) => onToggle(index, value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddonCheckboxTile extends StatelessWidget {
  const _AddonCheckboxTile({
    required this.addon,
    required this.selected,
    required this.onChanged,
  });

  final _VenueAddon addon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF1FA2FF)
                : Colors.white.withValues(alpha: 0.18),
          ),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: const Color(0xFF1FA2FF),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          addon.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(addon.price),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8AE8FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (addon.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        addon.description,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.pricePerSession,
    required this.onTapBook,
  });

  final int pricePerSession;
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
                      _formatPriceLabel(pricePerSession),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
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
    required this.disabledDayKeys,
    required this.selectedAddons,
    required this.bookedRanges,
    required this.bookedHoursByDay,
    required this.phoneNumber,
  });

  final int pricePerSession;
  final String venueName;
  final Set<int> disabledDayKeys;
  final Future<_BookingSummary> Function(
    DateTime startDate,
    DateTime endDate,
    String phoneNumber,
    List<_VenueAddon> selectedAddons,
  )
  onSubmit;
  final List<_VenueAddon> selectedAddons;
  final List<_BookedDateRange> bookedRanges;
  final Map<int, List<_DailyHourRange>> bookedHoursByDay;
  final String phoneNumber;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

  class _BookingDialogState extends State<_BookingDialog> {
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _error;
  bool _submitting = false;
  int? _startHour;
  int? _endHour;

  DateTime _normalizeDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isDateDisabled(DateTime date) =>
      widget.disabledDayKeys.contains(_dayKeyFromDate(date));

  bool _rangeOverlapsDisabled(DateTime start, DateTime end) {
    var cursor = _normalizeDate(start);
    final last = _normalizeDate(end);
    while (!cursor.isAfter(last)) {
      if (_isDateDisabled(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
    var normalized = _normalizeDate(value);
    if (normalized.isBefore(min)) normalized = min;
    if (normalized.isAfter(max)) normalized = max;
    return normalized;
  }

  DateTime? _nextSelectableDate(DateTime start, DateTime lastDate) {
    var cursor = _normalizeDate(start);
    while (!cursor.isAfter(lastDate)) {
      if (!_isDateDisabled(cursor)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  DateTime? get _startDateTime {
    if (_startDate == null || _startHour == null) return null;
    return _combineDateAndHour(_startDate!, _startHour!);
  }

  DateTime? get _endDateTime {
    if (_endDate == null || _endHour == null) return null;
    return _combineDateAndHour(_endDate!, _endHour!, isEnd: true);
  }

  DateTime _combineDateAndHour(
    DateTime date,
    int hour, {
    bool isEnd = false,
  }) {
    final base = DateTime(date.year, date.month, date.day);
    if (isEnd && hour >= 24) {
      return base.add(const Duration(days: 1));
    }
    return base.add(Duration(hours: hour));
  }

  bool _isRangeAvailable(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return false;
    for (final range in widget.bookedRanges) {
      if (range.overlaps(start, end)) {
        return false;
      }
    }
    return true;
  }

  List<int> _availableStartHours() {
    final date = _startDate;
    if (date == null) return const [];
    final dayKey = _dayKeyFromDate(date);
    final blocked = widget.bookedHoursByDay[dayKey] ?? const <_DailyHourRange>[];
    final hours = <int>[];
    for (var hour = 0; hour < 24; hour++) {
      final slotStart = hour.toDouble();
      final slotEnd = slotStart + 1;
      final overlaps = blocked.any((range) => range.overlaps(slotStart, slotEnd));
      if (!overlaps) {
        hours.add(hour);
      }
    }
    return hours;
  }

  List<int> _availableEndHours() {
    final endDate = _endDate;
    final startDateTime = _startDateTime;
    final startDate = _startDate;
    if (endDate == null || startDateTime == null || startDate == null) {
      return const [];
    }
    final isSameDay = _normalizeDate(startDate).isAtSameMomentAs(
      _normalizeDate(endDate),
    );
    final minHour = isSameDay && _startHour != null ? _startHour! + 1 : 1;
    final hours = <int>[];
    for (var hour = minHour; hour <= 24; hour++) {
      final candidateEnd = _combineDateAndHour(endDate, hour, isEnd: true);
      if (!candidateEnd.isAfter(startDateTime)) continue;
      if (_isRangeAvailable(startDateTime, candidateEnd)) {
        hours.add(hour);
      }
    }
    return hours;
  }

  void _showBlockedSnack(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  int _sessionCount() {
    if (_startDate == null || _endDate == null) return 0;
    final diff = _endDate!.difference(_startDate!);
    final hours = diff.inHours;
    return hours <= 0 ? 0 : hours;
  }

  int get _selectedAddonsTotalExternal {
    if (widget.selectedAddons.isEmpty) return 0;
    return widget.selectedAddons.fold<int>(
      0,
      (sum, addon) => sum + addon.price,
    );
  }

  int _estimatedSubtotal() {
    final sessions = _sessionCount();
    final base = sessions > 0 ? sessions * widget.pricePerSession : 0;
    return base + _selectedAddonsTotalExternal;
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = _normalizeDate(DateTime.now());
    final lastDate = today.add(const Duration(days: 365));
    var firstDate = isStart ? today : (_startDate ?? today);
    firstDate = _clampDate(firstDate, today, lastDate);
    var initial = isStart
        ? (_startDate ?? firstDate)
        : (_endDate ?? _startDate ?? firstDate);
    initial = _clampDate(initial, firstDate, lastDate);
    final selectableInitial = _nextSelectableDate(initial, lastDate);
    if (selectableInitial == null) {
      _showBlockedSnack(
        'Tidak ada tanggal tersedia dalam 1 tahun ke depan.',
      );
      return;
    }
    if (firstDate.isAfter(selectableInitial)) {
      firstDate = selectableInitial;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: selectableInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => !_isDateDisabled(day),
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
    final normalized = _normalizeDate(picked);
    if (_isDateDisabled(normalized)) {
      _showBlockedSnack('Tanggal ini sudah dibooking. Pilih tanggal lain.');
      return;
    }
    if (isStart) {
      DateTime? newEnd = _endDate;
      if (newEnd != null && newEnd.isBefore(normalized)) {
        newEnd = normalized;
      }
      final overlaps =
          newEnd != null && _rangeOverlapsDisabled(normalized, newEnd);
      setState(() {
        _startDate = normalized;
        _startCtrl.text = _formatReadableDate(normalized);
        if (overlaps) {
          _endDate = null;
          _endCtrl.clear();
          _endHour = null;
        } else {
          _endDate = newEnd;
          if (newEnd != null) {
            _endCtrl.text = _formatReadableDate(newEnd);
          }
        }
        _startHour = null;
        _endHour = null;
        _error = null;
      });
      if (overlaps) {
        _showBlockedSnack(
          'Tanggal akhir sebelumnya bertabrakan. Pilih ulang tanggal selesai.',
        );
      }
      return;
    }
    if (_startDate != null && normalized.isBefore(_startDate!)) {
      _showBlockedSnack('Tanggal selesai tidak boleh sebelum tanggal mulai.');
      return;
    }
    if (_startDate != null && _rangeOverlapsDisabled(_startDate!, normalized)) {
      _showBlockedSnack(
        'Rentang tanggal tersebut sudah dibooking. Pilih rentang lain.',
      );
      return;
    }
    setState(() {
      _endDate = normalized;
      _endCtrl.text = _formatReadableDate(normalized);
      _endHour = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final phone = widget.phoneNumber.trim();
    final startDateTime = _startDateTime;
    final endDateTime = _endDateTime;
    if (startDateTime == null || endDateTime == null) {
      setState(
        () => _error =
            'Mohon pilih tanggal serta jam mulai/selesai.',
      );
      return;
    }
    if (phone.isEmpty) {
      setState(
        () =>
            _error = 'Nomor telepon tidak tersedia. Perbarui di pengaturan akun.',
      );
      return;
    }
    if (!endDateTime.isAfter(startDateTime)) {
      setState(
        () => _error = 'Jam selesai harus setelah jam mulai.',
      );
      return;
    }
    if (_rangeOverlapsDisabled(startDateTime, endDateTime)) {
      setState(
        () => _error =
            'Rentang tanggal bertabrakan dengan booking lain. Pilih rentang berbeda.',
      );
      return;
    }
    if (!_isRangeAvailable(startDateTime, endDateTime)) {
      setState(
        () => _error =
            'Rentang jam tersebut sudah dibooking. Pilih jam lain.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final summary = await widget.onSubmit(
        startDateTime,
        endDateTime,
        phone,
        widget.selectedAddons,
      );
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
    final startHourOptions = _availableStartHours();
    final endHourOptions = _availableEndHours();
    return _GlassPanel(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      overlayColor: const Color(0xFF0F2037),
      useGradient: false,
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
            '${_formatPriceLabel(widget.pricePerSession)} ï¿½ ${widget.venueName}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              final startDateField = _DateField(
                label: 'Mulai',
                value: _startCtrl.text,
                hint: 'Pilih tanggal',
                onTap: () => _pickDate(isStart: true),
              );
              final endDateField = _DateField(
                label: 'Selesai',
                value: _endCtrl.text,
                hint: 'Pilih tanggal',
                onTap: () => _pickDate(isStart: false),
              );
              final startHourField = _HourDropdownField(
                label: 'Jam mulai',
                value: _startHour,
                options: startHourOptions,
                dense: !isCompact,
                hint: _startDate == null
                    ? 'Pilih tanggal mulai lebih dulu'
                    : startHourOptions.isEmpty
                        ? 'Tidak ada jam tersedia'
                        : 'Pilih jam mulai',
                onChanged: (value) {
                  setState(() {
                    _startHour = value;
                    _endHour = null;
                  });
                },
              );
              final endHourField = _HourDropdownField(
                label: 'Jam selesai',
                value: _endHour,
                options: endHourOptions,
                dense: !isCompact,
                hint: _startHour == null
                    ? 'Pilih jam mulai lebih dulu'
                    : _endDate == null
                        ? 'Pilih tanggal selesai lebih dulu'
                        : endHourOptions.isEmpty
                            ? 'Tidak ada jam selesai tersedia'
                            : 'Pilih jam selesai',
                onChanged: (value) {
                  setState(() {
                    _endHour = value;
                  });
                },
              );
              if (isCompact) {
                return Column(
                  children: [
                    startDateField,
                    const SizedBox(height: 16),
                    startHourField,
                    const SizedBox(height: 16),
                    endDateField,
                    const SizedBox(height: 16),
                    endHourField,
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: startDateField),
                      const SizedBox(width: 16),
                      Expanded(child: startHourField),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: endDateField),
                      const SizedBox(width: 16),
                      Expanded(child: endHourField),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 18),
          _BookingSubtotalBanner(
            sessions: _sessionCount(),
            pricePerSession: widget.pricePerSession,
            addonsTotal: _selectedAddonsTotalExternal,
            subtotal: _estimatedSubtotal(),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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

class _BookingSubtotalBanner extends StatelessWidget {
  const _BookingSubtotalBanner({
    required this.sessions,
    required this.pricePerSession,
    required this.addonsTotal,
    required this.subtotal,
  });

  final int sessions;
  final int pricePerSession;
  final int addonsTotal;
  final int subtotal;

  @override
  Widget build(BuildContext context) {
    final hasDates = sessions > 0;
    final baseDescription = hasDates
        ? '$sessions sesi × ${_formatCurrency(pricePerSession)}'
        : 'Pilih rentang tanggal untuk menghitung sesi.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subtotal',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(subtotal),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add-ons: ${_formatCurrency(addonsTotal)}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            baseDescription,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
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
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
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
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    display,
                    style: GoogleFonts.plusJakartaSans(
                      color: value.isEmpty ? Colors.white54 : Colors.white,
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
      overlayColor: const Color(0xFF0F2037),
      useGradient: false,
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
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
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
          _ConfirmationRow(label: 'Total sesi', value: '${summary.sessions}x'),
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
          if (summary.selectedAddons.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ConfirmationRow(
              label: 'Add-ons',
              value: summary.selectedAddons
                  .map((addon) => addon.name)
                  .join(', '),
            ),
          ],
          const SizedBox(height: 8),
          _ConfirmationRow(label: 'Kontak', value: summary.phoneNumber),
          if ((summary.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _ConfirmationRow(label: 'Catatan', value: summary.notes!),
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
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
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

  class _BookedDateRange {
  const _BookedDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static _BookedDateRange? tryParse(Map<String, dynamic> map) {
    DateTime? parse(String key) {
      final raw = map[key];
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) return null;
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    final startRaw = parse('start_date');
    final endRaw = parse('end_date');
    if (startRaw == null || endRaw == null) return null;
    var normalizedStart = startRaw;
    var normalizedEnd = endRaw;
    if (!normalizedEnd.isAfter(normalizedStart)) {
      return null;
    }
    return _BookedDateRange(start: normalizedStart, end: normalizedEnd);
  }

  bool overlaps(DateTime otherStart, DateTime otherEnd) {
    // Treat ranges as half-open [start, end): end is exclusive.
    final candidateStart =
        otherStart.isBefore(otherEnd) ? otherStart : otherEnd;
    final candidateEnd =
        otherStart.isBefore(otherEnd) ? otherEnd : otherStart;
    // No overlap if candidate ends on/before this.start,
    // or starts on/after this.end.
    if (candidateEnd.isBefore(start) ||
        candidateEnd.isAtSameMomentAs(start)) {
      return false;
    }
    if (candidateStart.isAfter(end) ||
        candidateStart.isAtSameMomentAs(end)) {
      return false;
    }
    return true;
  }

  Iterable<DateTime> days() sync* {
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  bool coversDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final startsBefore = !start.isAfter(dayStart);
    final endsAfter = !end.isBefore(dayEnd);
    return startsBefore && endsAfter;
  }
}

class _HourDropdownField extends StatelessWidget {
  const _HourDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.hint,
    this.dense = false,
    this.maxLines = 1,
  });

  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;
  final String hint;
  final bool dense;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final disabled = options.isEmpty;
    final gap = dense ? 4.0 : 6.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
        SizedBox(height: gap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: disabled ? null : value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F1D3C),
              icon: const Icon(Icons.expand_more, color: Colors.white70),
              selectedItemBuilder: (context) {
                return options.map((hour) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatHourLabel(hour),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList();
              },
              hint: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hint,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                  ),
                ),
              ),
              onChanged: disabled ? null : onChanged,
              items: options
                  .map(
                    (hour) => DropdownMenuItem(
                      value: hour,
                      child: Text(
                        _formatHourLabel(hour),
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

String _formatHourLabel(int hour) {
  if (hour >= 24) {
    return '00:00 (besok)';
  }
  return '${hour.toString().padLeft(2, '0')}:00';
}

class _DailyHourRange {
  const _DailyHourRange({required this.startHour, required this.endHour});

  final double startHour;
  final double endHour;

  bool overlaps(double otherStart, double otherEnd) {
    // Half-open [startHour, endHour) vs [otherStart, otherEnd):
    // they overlap only when each starts before the other ends.
    return endHour > otherStart && startHour < otherEnd;
  }
}

int _dayKeyFromDate(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

class _BookingSummary {
  const _BookingSummary({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.venueType,
    required this.venueLocation,
    required this.venueDescription,
    required this.venueImageUrl,
    required this.venueImageAbsoluteUrl,
    required this.venuePrice,
    required this.startDate,
    required this.endDate,
    required this.sessions,
    required this.subtotal,
    required this.phoneNumber,
    required this.hasBeenPaid,
    required this.datePaid,
    required this.createdAt,
    required this.selectedAddons,
    required this.addonsTotal,
    required this.venueAddons,
    this.notes,
  });

  factory _BookingSummary.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? value) {
      final parsed = DateTime.tryParse(value ?? '');
      if (parsed == null) return DateTime.now();
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
    final venue = (json['venue'] as Map<String, dynamic>?) ?? const {};
    final rawImageUrl =
        (venue['image_absolute_url'] ?? venue['image_url'] ?? '').toString();
    final resolvedImageUrl = _resolveMediaUrlGlobal(rawImageUrl);
    final selectedAddons = (json['selected_addons'] is List)
        ? (json['selected_addons'] as List)
              .whereType<Map<String, dynamic>>()
              .map(_VenueAddon.fromMap)
              .toList()
        : const <_VenueAddon>[];
    final venueAddons = _VenueCardData._parseAddons(venue['addons']);
    final addonsTotal =
        (json['addons_total'] as num?)?.toInt() ??
        selectedAddons.fold<int>(0, (sum, addon) => sum + addon.price);
    return _BookingSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      venueId: (venue['id'] as num?)?.toInt() ?? 0,
      venueName: (venue['title'] ?? 'Venue').toString(),
      venueType: (venue['type'] ?? '').toString(),
      venueLocation: (venue['location'] ?? '').toString(),
      venueDescription: (venue['description'] ?? '').toString(),
      venueImageUrl: resolvedImageUrl,
      venueImageAbsoluteUrl: resolvedImageUrl,
      venuePrice: (venue['price'] as num?)?.toInt() ?? 0,
      startDate: parseDate(json['start_date']?.toString()),
      endDate: parseDate(json['end_date']?.toString()),
      sessions: (json['sessions'] as num?)?.toInt() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      phoneNumber: (json['contact_phone'] ?? '').toString(),
      hasBeenPaid: json['has_been_paid'] == true,
      datePaid: json['date_paid'] == null
          ? null
          : parseDate(json['date_paid']?.toString()),
      createdAt: parseDate(json['created_at']?.toString()),
      selectedAddons: selectedAddons,
      addonsTotal: addonsTotal,
      venueAddons: venueAddons,
      notes: json['notes']?.toString(),
    );
  }

  factory _BookingSummary.localMock({
      required String venueName,
      required int venuePrice,
      required DateTime startDate,
      required DateTime endDate,
      required String phoneNumber,
      List<_VenueAddon> selectedAddons = const [],
    }) {
      final diff = endDate.difference(startDate);
      final sessions = diff.inHours <= 0 ? 1 : diff.inHours;
    final now = DateTime.now();
    return _BookingSummary(
      id: now.millisecondsSinceEpoch,
      venueId: 0,
      venueName: venueName,
      venueType: 'Venue',
      venueLocation: 'Jakarta, Indonesia',
      venueDescription: 'Booking simulasi untuk $venueName.',
      venueImageUrl: '',
      venueImageAbsoluteUrl: '',
      venuePrice: venuePrice,
      startDate: startDate,
      endDate: endDate,
        sessions: sessions,
        subtotal:
            sessions * venuePrice +
            selectedAddons.fold(0, (sum, addon) => sum + addon.price),
      phoneNumber: phoneNumber,
      hasBeenPaid: false,
      datePaid: null,
      createdAt: now,
      selectedAddons: selectedAddons,
      addonsTotal: selectedAddons.fold(0, (sum, addon) => sum + addon.price),
      venueAddons: const [],
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
  final String venueImageAbsoluteUrl;
  final int venuePrice;
  final DateTime startDate;
  final DateTime endDate;
  final int sessions;
  final int subtotal;
  final String phoneNumber;
  final bool hasBeenPaid;
  final DateTime? datePaid;
  final DateTime createdAt;
  final List<_VenueAddon> selectedAddons;
  final int addonsTotal;
  final List<_VenueAddon> venueAddons;
  final String? notes;
}

String _formatPriceLabel(int price) {
  if (price <= 0) return 'Check availability';
  // Price is per hour on both mobile and admin
  return '${_formatCurrency(price)} / jam';
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
