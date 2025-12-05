import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AuroraBackdropVariant { standard, dense }

class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({
    super.key,
    this.phase = 0,
    this.variant = AuroraBackdropVariant.standard,
    this.opacity = 1,
  });

  final double phase;
  final AuroraBackdropVariant variant;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * 2 * math.pi);
    final swell = math.cos(phase * 2 * math.pi);
    final configs =
        variant == AuroraBackdropVariant.dense ? _denseBands : _standardBands;
    return IgnorePointer(
      child: Stack(
        children: configs
            .map(
              (config) => _AuroraBand(
                config: config,
                wave: wave,
                swell: swell,
                opacity: opacity,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AuroraBandConfig {
  const _AuroraBandConfig({
    required this.alignment,
    required this.sway,
    required this.width,
    required this.height,
    required this.angle,
    required this.colors,
    this.blur = 120,
  });

  final Alignment alignment;
  final Alignment sway;
  final double width;
  final double height;
  final double angle;
  final List<Color> colors;
  final double blur;
}

const _standardBands = [
  _AuroraBandConfig(
    alignment: Alignment(-0.85, -0.7),
    sway: Alignment(0.12, 0.08),
    width: 240,
    height: 520,
    angle: -0.3,
    colors: [Color(0x663A98FF), Color(0x0026FFC8)],
    blur: 140,
  ),
  _AuroraBandConfig(
    alignment: Alignment(-0.05, -0.25),
    sway: Alignment(0.08, 0.06),
    width: 320,
    height: 640,
    angle: -0.18,
    colors: [Color(0x6624FFD5), Color(0x0028FF8B)],
    blur: 160,
  ),
  _AuroraBandConfig(
    alignment: Alignment(0.8, -0.4),
    sway: Alignment(0.12, 0.1),
    width: 260,
    height: 560,
    angle: 0.28,
    colors: [Color(0x665D3BFF), Color(0x003143FF)],
    blur: 130,
  ),
];

const _denseBands = [
  _AuroraBandConfig(
    alignment: Alignment(-0.9, -0.75),
    sway: Alignment(0.14, 0.1),
    width: 220,
    height: 540,
    angle: -0.35,
    colors: [Color(0x66FF7EC7), Color(0x003D32FF)],
    blur: 150,
  ),
  _AuroraBandConfig(
    alignment: Alignment(-0.4, -0.4),
    sway: Alignment(0.1, 0.08),
    width: 280,
    height: 600,
    angle: -0.2,
    colors: [Color(0x6635FFD8), Color(0x0029FFB3)],
    blur: 160,
  ),
  _AuroraBandConfig(
    alignment: Alignment(0.1, -0.2),
    sway: Alignment(0.08, 0.06),
    width: 320,
    height: 640,
    angle: -0.1,
    colors: [Color(0x6648FFE9), Color(0x0024A0FF)],
    blur: 150,
  ),
  _AuroraBandConfig(
    alignment: Alignment(0.65, -0.35),
    sway: Alignment(0.12, 0.08),
    width: 300,
    height: 620,
    angle: 0.32,
    colors: [Color(0x6645E5FF), Color(0x0033B8FF)],
    blur: 150,
  ),
  _AuroraBandConfig(
    alignment: Alignment(0.15, 0.35),
    sway: Alignment(0.1, 0.1),
    width: 360,
    height: 660,
    angle: -0.22,
    colors: [Color(0x6632FFB0), Color(0x001C76FF)],
    blur: 180,
  ),
];

class _AuroraBand extends StatelessWidget {
  const _AuroraBand({
    required this.config,
    required this.wave,
    required this.swell,
    required this.opacity,
  });

  final _AuroraBandConfig config;
  final double wave;
  final double swell;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final dx = config.alignment.x + wave * config.sway.x;
    final dy = config.alignment.y + swell * config.sway.y;
    final colors = config.colors
        .map(
          (color) => color.withValues(
            alpha: (color.a * opacity).clamp(0.0, 1.0),
          ),
        )
        .toList();

    return Align(
      alignment: Alignment(dx, dy),
      child: Transform.rotate(
        angle: config.angle + wave * 0.05,
        child: Container(
          width: config.width,
          height: config.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(config.width),
            boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: config.blur,
              spreadRadius: config.blur * 0.02,
            ),
            ],
          ),
        ),
      ),
    );
  }
}