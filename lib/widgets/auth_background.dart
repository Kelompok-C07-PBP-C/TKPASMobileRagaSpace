import 'package:flutter/material.dart';
import 'package:tk2ragaspace/theme/aurora_palette.dart';

import 'aurora_backdrop.dart';
import 'twinkle_overlay.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child, this.showEdgeWave = true});

  final Widget child;
  final bool showEdgeWave;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AuroraPalette.sky),
          ),
        ),
        const Positioned.fill(
          child: AuroraBackdrop(
            phase: 0.32,
            variant: AuroraBackdropVariant.dense,
            opacity: 0.85,
          ),
        ),
        const Positioned.fill(child: TwinkleOverlay(opacity: 0.14)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        if (showEdgeWave) ...[
          const Positioned(
            top: -4,
            left: 0,
            right: 0,
            child: EdgeWave(),
          ),
          const Positioned(
            bottom: -28,
            left: 0,
            right: 0,
            child: EdgeWave(flip: true),
          ),
        ],
        child,
      ],
    );
  }
}

class EdgeWave extends StatelessWidget {
  const EdgeWave({super.key, this.flip = false});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final wave = Opacity(
      opacity: 0.65,
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: CustomPaint(
          painter: _EdgeWavePainter(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.35),
                const Color(0xFF9CE9FF).withValues(alpha: 0.22),
                const Color(0xFF7C7BFF).withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
    if (!flip) return wave;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(1.0, -1.0),
      child: wave,
    );
  }
}

class _EdgeWavePainter extends CustomPainter {
  _EdgeWavePainter({required this.gradient});

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    final path = Path()
      ..lineTo(0, size.height * 0.55)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.95,
        size.width * 0.55,
        size.height * 0.2,
        size.width,
        size.height * 0.65,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgeWavePainter oldDelegate) {
    return oldDelegate.gradient != gradient;
  }
}
