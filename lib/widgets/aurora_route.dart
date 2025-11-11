import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AuroraWarpRoute<T> extends PageRouteBuilder<T> {
  AuroraWarpRoute(this.child)
      : super(
          transitionDuration: const Duration(milliseconds: 560),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, __, ___) => child,
        );

  final Widget child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );
    final blurCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );
    final glowCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.1, 0.95, curve: Curves.easeInOut),
    );
    final scaleCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.06, 1.0, curve: Curves.easeOutBack),
    );
    final fadeCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );
    final slideCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.15, 0.95, curve: Curves.easeOutCubic),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: curve,
            builder: (context, _) {
              final wave = math.sin(curve.value * math.pi);
              final swell = math.cos(curve.value * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: const [
                      Color(0xFF0B1D3F),
                      Color(0xFF122B5C),
                      Color(0xFF050913),
                    ],
                    radius: 1.4 - wave * 0.1,
                    center: Alignment(0.2 + wave * 0.4, -0.2 + swell * 0.3),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: glowCurve,
            builder: (context, _) {
              final glowShift = math.sin(glowCurve.value * math.pi);
              return Opacity(
                opacity: 0.45 * glowCurve.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [
                        Color(0x55FF6FDB),
                        Color(0x3346EFFF),
                        Color(0x0056E0FF),
                      ],
                      begin: Alignment(-1 + glowShift * 0.4, -0.8),
                      end: Alignment(0.8, 1 - glowShift * 0.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: blurCurve,
            builder: (context, _) {
              final fast = math.pow(blurCurve.value.clamp(0.0, 1.0), 0.45);
              final value = (1 - (fast as double)) * 42;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
                child: const SizedBox(),
              );
            },
          ),
        ),
        FadeTransition(
          opacity: fadeCurve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(slideCurve),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(scaleCurve),
              child: RotationTransition(
                turns:
                    Tween<double>(begin: -0.02, end: 0.0).animate(scaleCurve),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ZoomInRoute<T> extends PageRouteBuilder<T> {
  ZoomInRoute(this.child,
      {this.duration = const Duration(milliseconds: 480),
      this.reverseDuration = const Duration(milliseconds: 320)})
      : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          pageBuilder: (_, __, ___) => child,
        );

  final Widget child;
  final Duration duration;
  final Duration reverseDuration;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
        child: child,
      ),
    );
  }
}


