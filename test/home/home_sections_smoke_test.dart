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
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    homeSkipNetworkForTests = false;
    homeDisableNetworkImagesForTests = false;
  });

  testWidgets('HomeScreen builds hero, testimonials, promo, and navigation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Hero / top-of-page content.
    expect(find.text('ONLY ON RAGASPACE'), findsOneWidget);

    // Testimonials section header.
    expect(
      find.text('What they said about RagaSpace?'),
      findsOneWidget,
    );

    // Promo spotlight header.
    expect(find.text('Mulai Lebih Pintar'), findsOneWidget);

    // Bottom navigation items from nav_section.dart.
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
  });
}
