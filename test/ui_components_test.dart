import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/widgets/aurora_backdrop.dart';
import 'package:tk2ragaspace/widgets/aurora_route.dart';
import 'package:tk2ragaspace/widgets/gradient_button.dart';
import 'package:tk2ragaspace/widgets/hero_slideshow.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';

void main() {
  testWidgets('AuroraBackdrop renders bands for both variants', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: AuroraBackdrop(phase: 0.25, opacity: 0.8),
    ));
    expect(find.byType(AuroraBackdrop), findsOneWidget);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: AuroraBackdrop(
        phase: 0.75,
        variant: AuroraBackdropVariant.dense,
        opacity: 0.5,
      ),
    ));
    expect(find.byType(AuroraBackdrop), findsOneWidget);
  });

  testWidgets('HeroSlideshow renders pages and indicators', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HeroSlideshow())));
    expect(find.byType(PageView), findsOneWidget);
    // Slides contain the expected titles
    expect(find.text('Book Turf Instantly'), findsOneWidget);
    // Dots/indicators exist
    expect(find.byType(AnimatedContainer), findsWidgets);
  });

  testWidgets('GradientButton renders label and reacts to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GradientButton(
          label: 'Tap me',
          onPressed: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('Tap me'), findsOneWidget);
    await tester.tap(find.byType(GradientButton));
    expect(tapped, isTrue);
  });

  testWidgets('TwinkleOverlay paints with given opacity', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 100, height: 100, child: TwinkleOverlay(opacity: 0.3)),
    ));
    expect(find.byType(TwinkleOverlay), findsOneWidget);
  });

  testWidgets('AuroraWarpRoute builds a route with given widget', (tester) async {
    final route = AuroraWarpRoute(const Text('Hello'));
    expect(route, isA<PageRoute>());
  });
}
