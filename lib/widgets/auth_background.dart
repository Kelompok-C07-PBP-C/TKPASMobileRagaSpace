import 'package:flutter/material.dart';
import 'package:tk2ragaspace/theme/aurora_palette.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';

/// Shared background for auth-related screens (register, login, etc).
///
/// Matches the web-app "RagaSpace" look: deep navy gradient + soft cyan/teal
/// nebula glows and subtle star twinkles.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AuroraPalette.sky),
          ),
        ),
        const Positioned(
          top: -160,
          left: -160,
          child: _GlowOrb(
            size: 360,
            color: Color(0x6638BDF8),
            blur: 160,
          ),
        ),
        const Positioned(
          top: 120,
          right: -180,
          child: _GlowOrb(
            size: 420,
            color: Color(0x5538BDF8),
            blur: 170,
          ),
        ),
        const Positioned(
          bottom: -220,
          left: 40,
          child: _GlowOrb(
            size: 520,
            color: Color(0x3322C55E),
            blur: 200,
          ),
        ),
        const Positioned(
          bottom: -240,
          right: -180,
          child: _GlowOrb(
            size: 520,
            color: Color(0x331B89AE),
            blur: 220,
          ),
        ),
        const Positioned.fill(child: TwinkleOverlay(opacity: 0.16)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.52, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.blur,
  });

  final double size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: blur,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
  }
}
