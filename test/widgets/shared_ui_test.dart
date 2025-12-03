import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco/widgets/aurora_backdrop.dart';
import 'package:marco/widgets/twinkle_overlay.dart';

void main() {
  testWidgets('AuroraBackdrop renders bands for dense variant', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuroraBackdrop(
            phase: 0.5,
            variant: AuroraBackdropVariant.dense,
            opacity: 0.4,
          ),
        ),
      ),
    );

    expect(find.byType(AuroraBackdrop), findsOneWidget);
    // Aurora bands are Align widgets; dense variant defines several.
    expect(find.byType(Align), findsWidgets);
  });

  testWidgets('TwinkleOverlay respects opacity and ignores pointers',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TwinkleOverlay(opacity: 0.42)),
      ),
    );
    final opacity =
        tester.widget<Opacity>(find.descendant(of: find.byType(TwinkleOverlay), matching: find.byType(Opacity)));
    expect(opacity.opacity, closeTo(0.42, 0.001));
    expect(
      find.descendant(
        of: find.byType(TwinkleOverlay),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });
}
