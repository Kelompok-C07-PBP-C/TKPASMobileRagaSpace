import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:visibility_detector/visibility_detector.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const _apiBaseUrl = 'http://127.0.0.1:8000';
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
  static const List<_VenueCardData> _fallbackVenues = [
    _VenueCardData(
      category: 'Futsal',
      name: 'Aurora Sports Dome',
      location: 'Jakarta, Indonesia',
      description:
          'Indoor futsal pitch with climate control, lounge seating, and LED scoreboards.',
      price: 550000,
      rating: 4.9,
      imageUrl:
          'https://media.istockphoto.com/id/2172873491/photo/university-student-and-man-in-portrait-outdoor-on-campus-with-book-for-education-learning-and.jpg?s=612x612&w=0&k=20&c=0jJ62Pxg9qWg2DKCl0pVQmN1j618h01SXJ7DGdlpsZM=',
    ),
    _VenueCardData(
      category: 'Badminton',
      name: 'Harborview Badminton Center',
      location: 'Surabaya, Indonesia',
      description:
          'Six international-standard courts with sprung flooring and onsite stringing service.',
      price: 320000,
      rating: 4.8,
      imageUrl:
          'https://media.gettyimages.com/id/2063799507/photo/business-portrait-and-black-man-in-city-outdoor-for-career-or-job-of-businessman-face.jpg?s=612x612&w=gi&k=20&c=aV_6jGmVEE5WQR6F__JPMwAxJZiPBBIg-a0pdzKgL6A=',
    ),
    _VenueCardData(
      category: 'Basket',
      name: 'Summit Court Arena',
      location: 'Bandung, Indonesia',
      description:
          'Full-sized basketball court complete with seating for 500 and premium locker rooms.',
      price: 680000,
      rating: 4.7,
      imageUrl:
          'https://plus.unsplash.com/premium_photo-1689530775582-83b8abdb5020?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8cmFuZG9tJTIwcGVyc29ufGVufDB8fDB8fHww&fm=jpg&q=60&w=3000',
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
  bool _usingFallbackVenues = false;
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
                Image.asset('assets/hero_gradient.png', fit: BoxFit.cover),
                Container(),
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
              value: 'All cities',
              icon: Icons.location_on_outlined,
            ),
            _FilterInput(
              label: 'All categories',
              value: 'All categories',
              icon: Icons.watch_later_outlined,
            ),
            _FilterInput(
              label: 'Max price',
              value: 'Max Price',
              icon: Icons.attach_money_rounded,
            ),
          ];
          return Wrap(
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
            onTap: () {},
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
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _venuesError!,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    if (_venues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No venues available yet.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_usingFallbackVenues)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _DemoDataNotice(onRetry: () => _fetchTopVenues()),
          ),
        for (var i = 0; i < _venues.length; i++) ...[
          _FadeSlideIn(
            delay: Duration(milliseconds: 500 + i * 160),
            child: _VenueCard(data: _venues[i]),
          ),
          if (i != _venues.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _fetchTopVenues() async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/venues/top/?limit=3');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw Exception('Failed to load venues');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final venues = data
          .map(
            (raw) => _VenueCardData(
              category: (raw['type'] ?? '').toString(),
              name: (raw['title'] ?? '').toString(),
              location: (raw['location'] ?? '').toString(),
              description: (raw['description'] ?? '').toString(),
              price: int.tryParse(raw['price'].toString()) ?? 0,
              rating: (raw['avg_rating'] ?? 0).toDouble(),
              imageUrl: (raw['image_url'] ?? '').toString(),
            ),
          )
          .toList();
      setState(() {
        if (venues.isEmpty) {
          _venues = List<_VenueCardData>.of(_fallbackVenues);
          _usingFallbackVenues = true;
        } else {
          _venues = venues;
          _usingFallbackVenues = false;
        }
        _loadingVenues = false;
        _venuesError = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _venues = List<_VenueCardData>.of(_fallbackVenues);
        _usingFallbackVenues = true;
        _loadingVenues = false;
        _venuesError = null;
      });
    }
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
            onTap: () => setState(() => _navIndex = 1),
          ),
          const SizedBox(width: 70),
          _NavItem(
            data: items[2],
            selected: _navIndex == 2,
            onTap: () => setState(() => _navIndex = 2),
          ),
          _NavItem(
            data: items[3],
            selected: _navIndex == 3,
            onTap: () => setState(() => _navIndex = 3),
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
    required this.icon,
  });

  final String label;
  final String value;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.expand_more, color: Colors.white70),
              ],
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.data});

  final _VenueCardData data;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 36,
      padding: const EdgeInsets.all(24),
      overlayColor: Colors.white.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: data.imageUrl.isNotEmpty
                  ? FadeInImage.assetNetwork(
                      placeholder: 'assets/hero_gradient.png',
                      image: data.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'assets/hero_gradient.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.category.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.location} • ${data.rating.toStringAsFixed(1)}/5',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0x331FA2FF),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  _formatPriceLabel(data.price),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View product'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.data});

  final _PromoCardData data;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 30,
      padding: const EdgeInsets.all(24),
      overlayColor: data.gradient.first.withValues(alpha: 0.18),
      borderColor: data.gradient.last.withValues(alpha: 0.35),
      boxShadow: [
        BoxShadow(
          color: data.gradient.last.withValues(alpha: 0.22),
          blurRadius: 40,
          offset: const Offset(0, 22),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 18),
          for (final bullet in data.bullets) ...[
            _PromoBullet(text: bullet),
            if (bullet != data.bullets.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PromoBullet extends StatelessWidget {
  const _PromoBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

}

class _DemoDataNotice extends StatelessWidget {
  const _DemoDataNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Showing demo venues',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start the backend server and tap retry to fetch real venues.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
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
            colors: [Color(0x6633478E), Color(0x000A0F1E)],
            shadowColor: Color(0x4433478E),
            blur: 150,
            spread: 18,
          ),
          _Halo(
            alignment: Alignment(0.95 + swell * 0.22, -0.78 + wave * 0.05),
            size: 360 + wave * 40,
            colors: [Color(0x77FF8EC7), Color(0x000A0F1E)],
            shadowColor: Color(0x55FF8EC7),
            blur: 170,
            spread: 22,
          ),
          _Halo(
            alignment: Alignment(-0.35 + wave * 0.15, 0.1 + swell * 0.1),
            size: 300 + swell * 40,
            colors: [Color(0x44475B94), Color(0x000A0F1E)],
            shadowColor: Color(0x55FFCF70),
            blur: 160,
            spread: 18,
          ),
          _Halo(
            alignment: Alignment(0.35 + swell * 0.18, -0.05 + wave * 0.08),
            size: 280 + wave * 35,
            colors: [Color(0x44355FB5), Color(0x000A0F1E)],
            shadowColor: Color(0x5546E4C1),
            blur: 150,
            spread: 16,
          ),
          _Halo(
            alignment: Alignment(0.05 + wave * 0.12, 0.7 + swell * 0.08),
            size: 520 + wave * 56,
            colors: [Color(0x55304D8E), Color(0x000A0F1E)],
            shadowColor: Color(0x3A304D8E),
            blur: 220,
            spread: 16,
          ),
          _Halo(
            alignment: Alignment(0.05 + wave * 0.12, 0.7 + swell * 0.08),
            size: 520 + wave * 56,
            colors: [Color(0x8835F7FF), Color(0x000A0F1E)],
            shadowColor: Color(0x55304D8E),
            blur: 220,
            spread: 16,
          ),
          Positioned(
            top: 140 + swell * 18,
            left: -120 + wave * 26,
            child: _LightRibbon(
              width: 320,
              height: 280,
              colors: [Color(0x30FFFFFF), Color(0x00223B6E)],
            ),
          ),
          Positioned(
            right: -100 + wave * 30,
            bottom: 80 + swell * 24,
            child: _LightRibbon(
              width: 280,
              height: 300,
              colors: [Color(0x18FFFFFF), Color(0x402D4E8F)],
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
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.02),
                ],
                stops: const [0.0, 0.35, 1.0],
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

class _LightRibbon extends StatelessWidget {
  const _LightRibbon({
    required this.width,
    required this.height,
    required this.colors,
  });
  final double width;
  final double height;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.4,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height * 0.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.4),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
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

class _CategoryChipData {
  const _CategoryChipData({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _HighlightCardData {
  const _HighlightCardData({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
}

class _PromoCardData {
  const _PromoCardData({
    required this.title,
    required this.description,
    required this.bullets,
    required this.gradient,
    required this.icon,
  });
  final String title;
  final String description;
  final List<String> bullets;
  final List<Color> gradient;
  final IconData icon;
}

class _VenueCardData {
  const _VenueCardData({
    required this.category,
    required this.name,
    required this.location,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
  });
  final String category;
  final String name;
  final String location;
  final String description;
  final int price;
  final double rating;
  final String imageUrl;
}

String _formatPriceLabel(int price) {
  if (price <= 0) return 'Check availability';
  final digits = price.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final needsSeparator = i != 0 && (digits.length - i) % 3 == 0;
    if (needsSeparator) buffer.write('.');
    buffer.write(digits[i]);
  }
  return 'Rp ${buffer.toString()} / sesi';
}

class _TestimonialData {
  const _TestimonialData({
    required this.name,
    required this.role,
    required this.quote,
    required this.avatarUrl,
  });
  final String name;
  final String role;
  final String quote;
  final String avatarUrl;
}
