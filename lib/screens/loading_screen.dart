import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../widgets/aurora_route.dart';
import 'home_screen.dart';

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
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AuroraWarpRoute(const HomeScreen()),
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
              builder: (context, child) {
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
