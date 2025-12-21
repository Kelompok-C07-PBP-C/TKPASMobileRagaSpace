import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tk2ragaspace/features/admin/admin_dashboard_screen.dart';
import 'package:tk2ragaspace/services/api.dart';
import 'package:tk2ragaspace/theme/aurora_palette.dart';
import 'package:tk2ragaspace/widgets/aurora_backdrop.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';
import '../../widgets/aurora_route.dart';
import '../home/home_screen.dart';

@visibleForTesting
bool loadingScreenDisableAutoNavigateForTests = false;

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
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
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    if (loadingScreenDisableAutoNavigateForTests) return;
    final adminFuture = Api().resolveAdminStatus();
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    Widget destination = const HomeScreen();
    try {
      final isAdmin = await adminFuture.timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (isAdmin) {
        destination = const AdminDashboardScreen();
      }
    } catch (_) {
      // Fall back to the user home screen when the backend is unreachable.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(AuroraWarpRoute(destination));
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _haloController.dispose();
    super.dispose();
  }

  @visibleForTesting
  Future<void> debugNavigateToHomeImmediatelyForTests() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AuroraWarpRoute(const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AuroraPalette.sky,
              ),
            ),
          ),
          const Positioned.fill(
            child: TwinkleOverlay(opacity: 0.2),
          ),
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
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Center(
            child: _buildLoader(),
          ),
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
              colors: [
                Color(0x66122B4C),
                Color(0x33328D76),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF31FFD2).withValues(alpha: 0.35),
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
                'Preparing your dashboard',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stitching together schedules, venues,\n'
                'and data insights\u2014hang tight.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
