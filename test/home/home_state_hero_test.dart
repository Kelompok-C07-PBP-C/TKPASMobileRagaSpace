import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    homeSkipNetworkForTests = true;
    homeDisableNetworkImagesForTests = true;
    debugSetFadeSlideInDisabledForTests(true);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    homeSkipNetworkForTests = false;
    homeDisableNetworkImagesForTests = false;
    debugSetFadeSlideInDisabledForTests(false);
  });

  testWidgets(
      '_HomeScreenState debug helpers toggle sticky nav and scroll timers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    final dynamic state = tester.state(find.byType(HomeScreen));

    // Exercise highlight and testimonial auto-scroll helpers.
    state.debugStartHighlightAutoScrollForTests();
    state.debugPauseHighlightAutoScrollForTests();
    state.debugStartTestimonialAutoScrollForTests();
    state.debugPauseTestimonialAutoScrollForTests();

    // Sticky nav stays visible so profile menu is always discoverable.
    expect(state.debugStickyNavVisibleForTests(), isTrue);
    state.debugHandleScrollForTests(150);
    expect(state.debugStickyNavVisibleForTests(), isTrue);
  });

  testWidgets('_HomeHeroSection builds search card and navigation bar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    // Hero heading text.
    expect(find.text('ONLY ON RAGASPACE'), findsOneWidget);

    // Search card content (filter labels in uppercase).
    expect(find.text('ALL CITIES'), findsWidgets);
    expect(find.text('ALL CATEGORIES'), findsWidgets);
    expect(find.text('MAX PRICE'), findsWidgets);

    // Navigation bar avatar and brand.
    expect(find.text('RagaSpace'), findsOneWidget);
    expect(find.text('Premium venues'), findsOneWidget);

    // Let any FadeSlideIn timers complete to avoid pending timers.
    await tester.pump(const Duration(milliseconds: 200));
  });
}
