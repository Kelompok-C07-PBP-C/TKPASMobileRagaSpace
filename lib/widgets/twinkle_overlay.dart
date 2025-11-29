import 'package:flutter/material.dart';

class TwinkleOverlay extends StatelessWidget {
  const TwinkleOverlay({super.key, this.opacity = 0.18});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/twinkle_stars.png'),
              repeat: ImageRepeat.repeat,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
      ),
    );
  }
}