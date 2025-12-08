part of 'package:tk2ragaspace/features/home/home_screen.dart';

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

@visibleForTesting
Widget buildVenueLoadingTestShell() {
  final venue = _VenueCardData(
    category: 'Futsal',
    name: 'Test Venue',
    location: 'Jakarta',
    description: 'Indoor futsal court',
    price: 100000,
    rating: 4.5,
    imageUrl: '',
    id: 1,
    addons: const [],
  );
  return _VenueDetailLoadingScreen(
    data: venue,
    apiBaseUrl: _apiBaseUrl,
    isFavorite: false,
    onToggleFavorite: (_) async => true,
    accountPhoneNumber: '08123',
  );
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
