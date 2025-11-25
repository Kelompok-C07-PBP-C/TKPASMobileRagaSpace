part of 'package:marco/features/home/home_screen.dart';

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

@visibleForTesting
bool homeDisableNetworkImagesForTests = false;

@visibleForTesting
bool homeSkipNetworkForTests = false;

final String _apiBaseUrl = resolveBaseApiHost();
final String _apiHostBase = _apiBaseUrl.replaceFirst(
  RegExp(r'/api/?$'),
  '',
);
const List<_CategoryChipData> _categories = [
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
const List<_HighlightCardData> _highlightCards = [
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
const List<_TestimonialData> _testimonials = [
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

abstract class _HomeScreenCore extends State<HomeScreen>
    with TickerProviderStateMixin {
  List<_VenueCardData> _venues = [];
  bool _loadingVenues = true;
  String? _venuesError;
  bool _venuesCanRetry = false;
  String _selectedCity = _filterCities.first;
  String _selectedCategory = _filterCategories.first;
  String _selectedPrice = _filterPrices.first;

  List<_VenueCardData> _wishlist = [];
  Set<String> _wishlistKeys = {};
  SharedPreferences? _prefs;
  String? _avatarUrl;
  String? _accountPhoneNumber;

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

  int get _highlightPageCount => _highlightCards.length + 1;

  Future<void> _openCatalog({
    String? initialCity,
    String? initialCategory,
    String? initialPrice,
  });
  Future<void> _openWishlist();
  Future<void> _openBookings();
  Future<void> _openVenueDetail(_VenueCardData data);
  List<_VenueCardData> get _filteredVenues;
  Widget _buildSectionHeader(String title, String? subtitle);
  Future<void> _syncWishlistFromServer({
    List<_VenueCardData>? localSeed,
    bool silent = false,
  });
  Future<void> _loadProfileSummary();
  Future<void> _toggleWishlist(_VenueCardData data);
  Future<bool> _toggleWishlistAndReturn(_VenueCardData data);

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
          _highlightController.page?.round() ?? _highlightController.initialPage;
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
}

class _HomeScreenState extends _HomeScreenCore
    with
        _HomeWishlistSection,
        _HomeHeroSection,
        _HomeTopVenuesSection,
        _HomeTestimonialsSection,
        _HomePromoSection,
        _HomeNavigationSection {
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
    if (!homeSkipNetworkForTests) {
      _fetchTopVenues();
      _loadWishlist();
      _loadProfileSummary();
    }
  }

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

  // === Debug helpers for tests ===

  @visibleForTesting
  void debugStartHighlightAutoScrollForTests() => _startHighlightAutoScroll();

  @visibleForTesting
  void debugPauseHighlightAutoScrollForTests() => _pauseHighlightAutoScroll();

  @visibleForTesting
  void debugStartTestimonialAutoScrollForTests() =>
      _startTestimonialAutoScroll();

  @visibleForTesting
  void debugPauseTestimonialAutoScrollForTests() =>
      _pauseTestimonialAutoScroll();

  @visibleForTesting
  void debugHandleScrollForTests(num offset) {
    _scrollController.jumpTo(offset.toDouble());
    _handleScroll();
  }

  @visibleForTesting
  bool debugStickyNavVisibleForTests() => _stickyNavVisible;
}
