import 'package:flutter/material.dart';

/// Soft warp-style page route used across the app for primary navigations.
class AuroraWarpRoute<T> extends PageRouteBuilder<T> {
  AuroraWarpRoute(
    this.child, {
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 650),
  }) : super(
          settings: settings,
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved);
            final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
        );

  final Widget child;
}

/// Simple zoom-in route for lightweight dialogs and cards.
class ZoomInRoute<T> extends PageRouteBuilder<T> {
  ZoomInRoute(
    this.child, {
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 320),
  }) : super(
          settings: settings,
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
            final scale = Tween<double>(begin: 0.9, end: 1.0).animate(curved);
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            );
          },
        );

  final Widget child;
}
