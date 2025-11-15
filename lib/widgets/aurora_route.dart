import 'package:flutter/material.dart';

/// Route with no animations to keep transitions instant.
class AuroraWarpRoute<T> extends PageRouteBuilder<T> {
  AuroraWarpRoute(this.child)
      : super(
          transitionDuration: const Duration(milliseconds: 160),
          reverseTransitionDuration: const Duration(milliseconds: 130),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuad,
              reverseCurve: Curves.easeInQuad,
            );
            final offsetTween = Tween<Offset>(
              begin: const Offset(0, 0.03),
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
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 140),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuad,
              reverseCurve: Curves.easeInQuad,
            );
            final scale = Tween<double>(begin: 0.98, end: 1).animate(curve);
            return FadeTransition(
              opacity: curve,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
        );

  final Widget child;
}
