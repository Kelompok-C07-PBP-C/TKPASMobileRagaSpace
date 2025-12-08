import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020308), Color(0xFF050608)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF4A261).withValues(alpha: 0.0),
                        const Color(0xFFE9C46A).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      radius: 1.2 + 0.05 * math.sin(2 * math.pi * t),
                      center: Alignment(
                        -0.6 + 0.1 * math.sin(2 * math.pi * t),
                        -1.0 + 0.06 * math.cos(2 * math.pi * t),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _GoldWavePainter(progress: t)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _GoldWavePainter extends CustomPainter {
  _GoldWavePainter({required this.progress});

  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    Paint makePaint(List<Color> colors, Alignment begin, Alignment end) {
      return Paint()
        ..shader = LinearGradient(
          colors: colors,
          begin: begin,
          end: end,
        ).createShader(rect);
    }

    final wobble = math.sin(2 * math.pi * progress);
    final midPhase = math.sin(2 * math.pi * (progress + 0.33));
    final bottomPhase = math.sin(2 * math.pi * (progress + 0.66));

    final topOffset = size.height * 0.02 * wobble;
    final midOffset = size.height * 0.025 * midPhase;
    final bottomOffset = size.height * 0.03 * bottomPhase;

    final topWave = Path()
      ..moveTo(0, size.height * 0.16)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.05 + topOffset,
        size.width * 0.38,
        size.height * 0.26 + topOffset,
        size.width * 0.66,
        size.height * 0.12 + topOffset,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.04 + topOffset,
        size.width,
        size.height * 0.2 + topOffset,
        size.width,
        size.height * 0.06 + topOffset,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(
      topWave,
      makePaint(
        [
          Colors.transparent,
          const Color(0xFFE9C46A).withValues(alpha: 0.6),
          Colors.transparent,
        ],
        Alignment.centerLeft,
        Alignment.centerRight,
      ),
    );

    final midWave = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.44 + midOffset,
        size.width * 0.46,
        size.height * 0.68 + midOffset,
        size.width * 0.76,
        size.height * 0.5 + midOffset,
      )
      ..cubicTo(
        size.width * 0.94,
        size.height * 0.4 + midOffset,
        size.width,
        size.height * 0.64 + midOffset,
        size.width,
        size.height * 0.46 + midOffset,
      )
      ..lineTo(size.width, size.height * 0.22)
      ..lineTo(0, size.height * 0.32)
      ..close();

    canvas.drawPath(
      midWave,
      makePaint(
        [
          Colors.transparent,
          const Color(0xFFF4A261).withValues(alpha: 0.52),
          Colors.transparent,
        ],
        Alignment.bottomLeft,
        Alignment.topRight,
      ),
    );

    final bottomWave = Path()
      ..moveTo(0, size.height * 0.96 + bottomOffset)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.9 + bottomOffset,
        size.width * 0.4,
        size.height + bottomOffset,
        size.width * 0.72,
        size.height * 0.9 + bottomOffset,
      )
      ..cubicTo(
        size.width * 0.95,
        size.height * 0.84 + bottomOffset,
        size.width,
        size.height * 0.99 + bottomOffset,
        size.width,
        size.height * 0.9 + bottomOffset,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      bottomWave,
      makePaint(
        [
          Colors.transparent,
          const Color(0xFFE9C46A).withValues(alpha: 0.4),
          Colors.transparent,
        ],
        Alignment.centerLeft,
        Alignment.centerRight,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
