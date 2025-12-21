import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:tk2ragaspace/features/admin/admin_theme.dart';

class AdminBackground extends StatelessWidget {
  const AdminBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: AdminPalette.backgroundBase),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.22,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Transform.scale(
                  scale: 1.25,
                  child: const Image(
                    image: AssetImage('assets/hero_gradient.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment(0.15, -0.1),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.88, -1.15),
                radius: 1.2,
                colors: [
                  Color(0x426366F1), // rgba(99, 102, 241, 0.26)
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.64, -1.0),
                radius: 1.25,
                colors: [
                  Color(0x4D93C5FD), // rgba(147, 197, 253, 0.3)
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.65, 0.62),
                radius: 1.35,
                colors: [
                  Color(0x4010B981), // rgba(16, 185, 129, 0.25)
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.92, 0.88),
                radius: 1.15,
                colors: [
                  Color(0x33EA580C), // rgba(234, 88, 12, 0.2)
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.05, 0.15),
                radius: 1.35,
                colors: [
                  Color(0x2B818CF8), // rgba(129, 140, 248, 0.17)
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: _AdminAuroraLeak()),
        const _AdminMeshBlob(
          alignment: Alignment(-0.92, -0.85),
          color: Color(0xFF7C8CFF),
          sigma: 90,
        ),
        const _AdminMeshBlob(
          alignment: Alignment(-1.12, 0.25),
          color: Color(0xFFF6A3C7),
          sigma: 95,
        ),
        const _AdminMeshBlob(
          alignment: Alignment(1.12, 0.92),
          color: Color(0xFF8BE4FF),
          sigma: 95,
        ),
        const _AdminMeshBlob(
          alignment: Alignment(0.65, -0.45),
          color: Color(0xFFB5F7DE),
          sigma: 85,
        ),
      ],
    );
  }
}

class _AdminMeshBlob extends StatelessWidget {
  const _AdminMeshBlob({
    required this.alignment,
    required this.color,
    required this.sigma,
  });

  final Alignment alignment;
  final Color color;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final diameter = (size.shortestSide * 0.86).clamp(340.0, 560.0);
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.58,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  backgroundBlendMode: BlendMode.screen,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.68,
                    colors: [
                      color,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAuroraLeak extends StatelessWidget {
  const _AdminAuroraLeak();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1.35,
          heightFactor: 0.72,
          child: ClipRect(
            child: Opacity(
              opacity: 0.82,
              child: Stack(
                children: [
                  Align(
                    alignment: const Alignment(-0.72, 0.95),
                    child: Transform.rotate(
                      angle: -0.32,
                      child: Container(
                        width: 380,
                        height: 620,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x8A2DF1C1),
                              Color(0x001C76FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(420),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D2DF1C1),
                              blurRadius: 280,
                              spreadRadius: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.62, 1.08),
                    child: Transform.rotate(
                      angle: 0.24,
                      child: Container(
                        width: 320,
                        height: 560,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x7A10B981),
                              Color(0x000EA5E9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(420),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4010B981),
                              blurRadius: 320,
                              spreadRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 260,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x0010B981),
                                Color(0x6610B981),
                                Color(0x400EA5E9),
                                Color(0x00020617),
                              ],
                              stops: [0.0, 0.55, 0.82, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
