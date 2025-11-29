import 'package:flutter/material.dart';

/// Shared palette utilities to keep every aurora-inspired surface consistent.
class AuroraPalette {
  const AuroraPalette._();

  /// Deep-sky gradient inspired by the provided aurora references.
  static const LinearGradient sky = LinearGradient(
    colors: [
      Color(0xFF01030C),
      Color(0xFF120B2F),
      Color(0xFF241852),
      Color(0xFF1A3D71),
      Color(0xFF0B5F63),
      Color(0xFF0AD794),
    ],
    stops: [0.0, 0.22, 0.45, 0.67, 0.83, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Returns a translucent gradient that mimics frosted glass without blurring.
  static LinearGradient glassGradient(Color tint) {
    final highlight = Color.lerp(tint, Colors.white, 0.45)!;
    final shadow = Color.lerp(tint, const Color(0xFF030A18), 0.65)!;
    final highlightOpacity = (tint.a + 0.35).clamp(0.0, 1.0).toDouble();
    final shadowOpacity = (tint.a + 0.15).clamp(0.0, 1.0).toDouble();
    return LinearGradient(
      colors: [
        highlight.withValues(alpha: highlightOpacity),
        shadow.withValues(alpha: shadowOpacity),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Soft sheen placed on ribbons/bands to simulate the aurora glow.
  static const LinearGradient ribbonSheen = LinearGradient(
    colors: [
      Color(0x44FFFFFF),
      Color(0x00000000),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}