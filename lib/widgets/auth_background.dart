import 'dart:math';
import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F9FF), Color(0xFFE9F0FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _GradientMesh()),
          const _BlurBadge(
            offset: Offset(-120, -90),
            diameter: 320,
            colors: [Color(0xFF8CC6FF), Color(0xFF748BFD)],
          ),
          const _BlurBadge(
            offset: Offset(150, 120),
            diameter: 240,
            colors: [Color(0xFFA0E1FF), Color(0xFFA7A3FF)],
          ),
          const _BlurBadge(
            offset: Offset(-50, 380),
            diameter: 260,
            colors: [Color(0xFFFED1FF), Color(0xFF98B3FF)],
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0.1),
                  ],
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

class _GradientMesh extends StatelessWidget {
  const _GradientMesh();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MeshPainter());
  }
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter();

  // Defines soft radial blobs that are layered together to emulate a gradient mesh.
  static const _blobs = [
    _BlobConfig(
      offset: Offset(0.12, 0.2),
      radiusFactor: 0.62,
      colors: <Color>[Color(0xFF4A8BFF), Color(0x004A8BFF)],
      scale: Size(1.25, 0.82),
    ),
    _BlobConfig(
      offset: Offset(0.85, 0.16),
      radiusFactor: 0.66,
      colors: <Color>[Color(0xFFFF7ACB), Color(0x00FF7ACB)],
      scale: Size(0.95, 1.12),
    ),
    _BlobConfig(
      offset: Offset(0.65, 0.79),
      radiusFactor: 0.7,
      colors: <Color>[Color(0xFF8C7CFF), Color(0x008C7CFF)],
      scale: Size(1.2, 0.9),
    ),
    _BlobConfig(
      offset: Offset(0.34, 0.76),
      radiusFactor: 0.58,
      colors: <Color>[Color(0xFFFFC27A), Color(0x00FFC27A)],
      scale: Size(0.82, 1.18),
    ),
    _BlobConfig(
      offset: Offset(0.3, 0.46),
      radiusFactor: 0.5,
      colors: <Color>[Color(0xFF60F2FF), Color(0x0060F2FF)],
      scale: Size(1.05, 1.05),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final basePaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFFF2F7FF),
          Color(0xFFF1EBFF),
          Color(0xFFFFF3EB),
        ],
        stops: <double>[0.0, 0.55, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    for (final blob in _blobs) {
      final center = Offset(
        size.width * blob.offset.dx,
        size.height * blob.offset.dy,
      );
      final radius = size.shortestSide * blob.radiusFactor;
      final shader = RadialGradient(
        colors: blob.colors,
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      final paint = Paint()..shader = shader;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(blob.scale.width, blob.scale.height);
      canvas.drawCircle(Offset.zero, radius, paint);
      canvas.restore();
    }

    canvas.save();
    canvas.translate(size.width * 0.76, size.height * 0.18);
    canvas.rotate(-pi / 12);
    final accentRadius = size.shortestSide * 0.52;
    final accentRect = Rect.fromCircle(
      center: Offset.zero,
      radius: accentRadius,
    );
    final accentPaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0x55FFB6F5), Color(0x004B63FF)],
      ).createShader(accentRect);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: accentRadius * 1.8,
        height: accentRadius,
      ),
      accentPaint,
    );
    canvas.restore();

    final highlightPath = Path()
      ..moveTo(size.width * -0.05, size.height * 0.72)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.32,
        size.width * 0.58,
        size.height * 0.58,
        size.width * 0.94,
        size.height * 0.32,
      )
      ..lineTo(size.width * 1.12, size.height * 0.9)
      ..lineTo(size.width * -0.1, size.height * 1.08)
      ..close();

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.4, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(highlightPath.getBounds());
    canvas.drawPath(highlightPath, highlightPaint);

    final bottomGlowCenter = Offset(size.width * 0.5, size.height * 1.02);
    final bottomGlowRect = Rect.fromCircle(
      center: bottomGlowCenter,
      radius: size.width * 0.95,
    );
    final bottomGlowPaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0x66FFB985), Color(0x00FFB985)],
      ).createShader(bottomGlowRect);
    canvas.drawOval(
      Rect.fromCenter(
        center: bottomGlowCenter,
        width: size.width * 1.9,
        height: size.height * 0.9,
      ),
      bottomGlowPaint,
    );

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.14),
        ],
        stops: const <double>[0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlobConfig {
  const _BlobConfig({
    required this.offset,
    required this.radiusFactor,
    required this.colors,
    this.scale = const Size(1, 1),
  });

  final Offset offset;
  final double radiusFactor;
  final List<Color> colors;
  final Size scale;
}

class _BlurBadge extends StatelessWidget {
  const _BlurBadge({
    required this.offset,
    required this.diameter,
    required this.colors,
  });

  final Offset offset;
  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx > 0 ? offset.dx : null,
      right: offset.dx < 0 ? -offset.dx : null,
      top: offset.dy > 0 ? offset.dy : null,
      bottom: offset.dy < 0 ? -offset.dy : null,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.first.withValues(alpha: 0.65),
                colors.last.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
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
      transform: Matrix4.rotationY(flip ? pi : 0),
      child: ClipPath(
        clipper: _WaveClipper(),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.45),
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
