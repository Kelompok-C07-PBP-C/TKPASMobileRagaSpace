import 'package:flutter/material.dart';

/// Route with no animations to keep transitions instant.
class AuroraWarpRoute<T> extends PageRouteBuilder<T> {
  AuroraWarpRoute(this.child)
      : super(
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final offsetTween = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: curve.drive(offsetTween),
                child: child,
              ),
            );
          },
        );

  final Widget child;
}

class ZoomInRoute<T> extends PageRouteBuilder<T> {
  ZoomInRoute(this.child)
      : super(
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final scale = Tween<double>(begin: 0.95, end: 1).animate(curve);
            return FadeTransition(
              opacity: curve,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
        );

  final Widget child;
}
