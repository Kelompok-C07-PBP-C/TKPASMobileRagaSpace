part of 'package:tk2ragaspace/features/home/home_screen.dart';

const List<String> _filterCities = [
  'All cities',
  'Jakarta',
  'Bandung',
  'Tangerang',
  'Yogyakarta',
  'Surabaya',
  'Makassar',
  'Denpasar',
  'Palembang',
  'Semarang',
  'Medan',
  'Depok',
];
const List<String> _filterCategories = [
  'All categories',
  'Padel',
  'Tennis',
  'Badminton',
  'Basket',
  'Sepak Bola',
  'Mini Soccer',
  'Futsal',
  'Billiard',
  'Tenis Meja',
  'Volley Ball',
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
    name: 'Rindu Aurellia',
    role: 'Koordinator Tim Futsal Anak Padi',
    quote:
        "Jujur, sebagai koordinator tim futsal 'Anak Padi', dulu saya yang paling stres setiap mau ngatur jadwal main. Prosesnya manual sekali: harus cari rekomendasi lapangan di Google, telepon atau WhatsApp adminnya satu-satu, lalu menunggu balasan mereka yang seringkali lama.\n\nSejak menemukan RagaSpace, semua masalah itu selesai. Aplikasinya benar-benar game-changer buat kami. Saya bisa lihat semua jadwal lapangan yang tersedia di sekitar kami secara real-time. Tinggal pilih jam, bayar, dan langsung dapat konfirmasi instan.",
    avatarUrl:
        'https://blogger.googleusercontent.com/img/a/AVvXsEha0jebkzt4VdaSYEd7LkT-ti2-zrf2MC5h6VjkSQNIf8x_6MgiJU6Qe3F7qF5F7mxXFXzTkSJoYhrf_YBy0rMEM-Hm8lg7iD063VW9TUvYaIhLVW5w_F5yUkZOfyPwG_gKp8ZEBKyyNLHDHrXXRuc5iEyTL4gUUIbdKHnenH50xaaPT6YmERUXZtneZlM',
  ),
  _TestimonialData(
    name: 'Tirta Siahaan',
    role: 'Pelatih Basket SMA Bima',
    quote:
        'RagaSpace bikin koordinasi latihan jadi jauh lebih gampang. Jadwalnya jelas dan bisa langsung saya bagi ke semua anak asuh lewat satu tautan.\n\nSebelumnya saya sering batalin latihan mendadak karena lapangan double booking. Sekarang semua terkontrol dengan notifikasi otomatisnya.',
    avatarUrl:
        'https://media.licdn.com/dms/image/v2/D4D03AQFor0aXg96udw/profile-displayphoto-scale_200_200/B4DZlQXhWGGQAY-/0/1757989968230?e=2147483647&v=beta&t=UM9XUoFuSC0-yfgjVC8ASzxQ-XrizT4Ru3hFCg9N6A0',
  ),
  _TestimonialData(
    name: 'Shafa Aurelia',
    role: 'Founder Komunitas Yoga Senja',
    quote:
        'Komunitas kami sering pindah venue, dan itu biasanya makan waktu untuk survei satu per satu. Lewat RagaSpace, saya bisa bandingkan fasilitas dengan cepat sebelum booking.\n\nPembayarannya praktis, ada invoice resmi, dan tim venue juga responsif karena sudah terintegrasi di sistem.',
    avatarUrl:
        'https://media.licdn.com/dms/image/v2/D4E03AQHvn66GQSiAXA/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724491188800?e=1762992000&v=beta&t=OI7oxBqbH9YG8_ZxuzZsfoFfFa8QdH2i2fHIOhMVVjA',
  ),
  _TestimonialData(
    name: 'Bilqis Nisrina',
    role: 'Marketing Manager Event Lokal',
    quote:
        'Kami sering gelar event komunitas, dan butuh venue yang bisa di-book jauh hari. RagaSpace kasih visibilitas penuh soal ketersediaan dan harga.\n\nTim supportnya juga proaktif, bantu negosiasi kebutuhan tambahan seperti sound system dan dekorasi.',
    avatarUrl:
        'https://media.licdn.com/dms/image/v2/D5603AQELb2yGe_q0JQ/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724513244165?e=1762992000&v=beta&t=oGa9zAMXOcfxUd-hO3N2lBfYPh9OUZ54lklyGbagTik',
  ),
  _TestimonialData(
    name: 'RPM Dimaz',
    role: 'Manajer Operasional Klub Badminton Orion',
    quote:
        'Dulu kami kesulitan memonitor jam sewa di semua lapangan. Sekarang, jadwal terpusat dan anggota klub bisa booking sesuai slot yang kami buka.\n\nLaporan transaksi bulanannya rapi, jadi mudah untuk evaluasi performa lapangan dan promo membership.',
    avatarUrl:
        'https://media.licdn.com/dms/image/v2/D4E03AQHOOsQevd2tfA/profile-displayphoto-crop_800_800/B4EZh.F_LjGoAM-/0/1754462158131?e=1762992000&v=beta&t=M5UyV43yFFtaWP5q8NRyznSVA4WHuN1K5FcKtQMsnP4',
  ),
  _TestimonialData(
    name: 'Haekal Dinova',
    role: 'Manajer Operasional Klub Badminton Orion',
    quote:
        'Dulu kami kesulitan memonitor jam sewa di semua lapangan. Sekarang, jadwal terpusat dan anggota klub bisa booking sesuai slot yang kami buka.\n\nLaporan transaksi bulanannya rapi, jadi mudah untuk evaluasi performa lapangan dan promo membership.',
    avatarUrl:
        'https://media.licdn.com/dms/image/v2/D5603AQHMK1Sfeqx7TQ/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724483982997?e=1762992000&v=beta&t=1-NFzYQQLxZbqPJP-UVUaAcNqYJUl1w1vlJEYGgeoZs',
  ),
];

abstract class _HomeScreenCore extends State<HomeScreen>
    with TickerProviderStateMixin {
  List<_VenueCardData> _venues = [];
  bool _loadingVenues = true;
  String? _venuesError;
  bool _venuesCanRetry = false;
  bool _isAuthenticated = false;
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
  bool _stickyNavVisible = true;
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
  Future<void> _loadWishlist();
  Future<void> _syncWishlistFromServer({
    List<_VenueCardData>? localSeed,
    bool silent = false,
  });
  Future<void> _loadProfileSummary();
  Future<void> _toggleWishlist(_VenueCardData data);
  Future<bool> _toggleWishlistAndReturn(_VenueCardData data);
  Future<List<_VenueCardData>> _syncWishlistForScreen();

  bool get _authenticated => _isAuthenticated && Api.currentUserId != null;

  Future<void> _bootstrapAuthSession() async {
    if (homeSkipNetworkForTests) return;

    try {
      await Api().me();
    } catch (_) {
      // ignore and fall back to stored credentials
    }
    if (!mounted) return;

    if (Api.currentUserId == null) {
      try {
        await Api.tryAutoLoginFromStorage();
      } catch (_) {
        // ignore
      }
    }
    if (!mounted) return;

    final nowAuthenticated = Api.currentUserId != null;
    if (nowAuthenticated != _isAuthenticated) {
      setState(() => _isAuthenticated = nowAuthenticated);
    }
    if (nowAuthenticated) {
      unawaited(_loadWishlist());
      unawaited(_loadProfileSummary());
      unawaited(() async {
        try {
          final isAdmin = await Api().resolveAdminStatus().timeout(
            const Duration(seconds: 4),
            onTimeout: () => Api.isAdmin,
          );
          if (!mounted || !isAdmin) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              AuroraWarpRoute(const AdminDashboardScreen()),
            );
          });
        } catch (_) {
          // ignore
        }
      }());
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (_authenticated) return true;

    final result = await Navigator.of(context).push<bool>(
      AuroraWarpRoute(const LoginScreen(returnToPrevious: true)),
    );
    if (!mounted) return false;

    final nowAuthenticated = (result == true) || Api.currentUserId != null;
    if (!nowAuthenticated) return false;

    setState(() => _isAuthenticated = true);
    unawaited(_loadWishlist());
    unawaited(_loadProfileSummary());

    try {
      final isAdmin = await Api().resolveAdminStatus().timeout(
        const Duration(seconds: 4),
        onTimeout: () => Api.isAdmin,
      );
      if (!mounted) return false;
      if (isAdmin) {
        Navigator.of(context).pushReplacement(
          AuroraWarpRoute(const AdminDashboardScreen()),
        );
        return false;
      }
    } catch (_) {
      // Ignore and proceed as a regular user session.
    }
    return true;
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
    _isAuthenticated = Api.currentUserId != null;
    _highlightController = PageController(viewportFraction: 0.9);
    _categoryMarqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _startHighlightAutoScroll();
    _startTestimonialAutoScroll();
    _scrollController = ScrollController();
    if (!homeSkipNetworkForTests) {
      _fetchTopVenues();
      _loadWishlist();
      _loadProfileSummary();
      unawaited(_bootstrapAuthSession());
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _testimonialTimer?.cancel();
    _highlightController.dispose();
    _categoryMarqueeController.dispose();
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
                    'Most booked venues on RagaSpace.',
                  ),
                  const SizedBox(height: 20),
                  _buildTopVenuesList(),
                  const SizedBox(height: 48),
                  _buildSectionHeader('What They said about RagaSpace?', null),
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
  }

  @visibleForTesting
  bool debugStickyNavVisibleForTests() => _stickyNavVisible;
}
