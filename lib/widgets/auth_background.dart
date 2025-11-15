import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:marco/theme/aurora_palette.dart';

import 'aurora_backdrop.dart';
import 'twinkle_overlay.dart';

/// Shared background for auth-related screens (register, forgot password, etc).
/// It keeps a persistent aurora theme without relying on blur-heavy blobs.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AuroraPalette.sky),
      child: Stack(
        children: [
          const Positioned.fill(
            child: AuroraBackdrop(
              variant: AuroraBackdropVariant.dense,
              opacity: 0.85,
            ),
          ),
          const Positioned.fill(
            child: TwinkleOverlay(opacity: 0.18),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class EdgeWave extends StatelessWidget {
  const EdgeWave({super.key, this.flip = false});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(flip ? math.pi : 0),
      child: ClipPath(
        clipper: _WaveClipper(),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 1.1,
        size.width * 0.55,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.2,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
