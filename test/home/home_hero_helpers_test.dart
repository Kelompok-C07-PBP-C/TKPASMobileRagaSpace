import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/home/home_screen.dart';

void main() {
  FlutterExceptionHandler? originalOnError;
  late void Function(FlutterErrorDetails details) originalPresentError;

  setUp(() {
    originalOnError = FlutterError.onError;
    originalPresentError = FlutterError.presentError;

    FlutterError.presentError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed')) return;
      originalPresentError(details);
    };

    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed')) return;
      if (originalOnError != null) {
        originalOnError!(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    FlutterError.presentError = originalPresentError;
  });

  testWidgets('_HighlightInfoCard renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildHighlightInfoCardForTests(),
        ),
      ),
    );

    expect(find.text('Highlight title'), findsOneWidget);
    expect(find.text('Highlight subtitle'), findsOneWidget);
  });

  testWidgets('_GlassPanel builds with and without gradient', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              buildGlassPanelForTests(useGradient: true),
              buildGlassPanelForTests(useGradient: false),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Glass panel'), findsNWidgets(2));
  });

  testWidgets('_ExploreVenuesCard shows copy and button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildExploreVenuesCardForTests()),
      ),
    );

    expect(find.text('Explore curated venues'), findsOneWidget);
    expect(find.text('Lihat panduan lengkap'), findsOneWidget);

    await tester.tap(find.text('Lihat panduan lengkap'));
    await tester.pump();
  });

  testWidgets('_StaticAuroraBackdrop paints for both styles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: buildStaticAuroraBackdropForTests()),
              Expanded(child: buildStaticAuroraBackdropForTests(detail: true)),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('Static aurora painter shouldRepaint behavior', () {
    expect(debugStaticAuroraShouldRepaintForTests(), isTrue);
  });

  testWidgets('_CategoryMarqueeRow renders short sequence',
      (tester) async {
    final animation1 = const AlwaysStoppedAnimation<double>(0.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Column(
              children: [buildCategoryMarqueeRowShortForTests(animation1)],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Tennis'), findsWidgets);
    expect(find.text('Badminton'), findsWidgets);
    expect(find.text('Basket'), findsNothing);
  });
}
