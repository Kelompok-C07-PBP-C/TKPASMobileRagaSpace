import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/authentication/loading_screen.dart';
import 'package:marco/features/home/home_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    loadingScreenDisableAutoNavigateForTests = true;
    homeSkipNetworkForTests = true;
    homeDisableNetworkImagesForTests = true;
    debugSetFadeSlideInDisabledForTests(true);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    loadingScreenDisableAutoNavigateForTests = false;
    homeSkipNetworkForTests = false;
    homeDisableNetworkImagesForTests = false;
    debugSetFadeSlideInDisabledForTests(false);
  });

  testWidgets('LoadingScreen shows loader and text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingScreen()));
    await tester.pump();

    expect(find.text('Preparing your dashboard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LoadingScreen can navigate to HomeScreen via debug helper',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingScreen()));
    await tester.pump();

    final dynamic state = tester.state(find.byType(LoadingScreen));
    await state.debugNavigateToHomeImmediatelyForTests();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
