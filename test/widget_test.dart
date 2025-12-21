import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tk2ragaspace/features/home/home_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:tk2ragaspace/main.dart';

Future<void> _pumpBriefly(WidgetTester tester, {int millis = 400}) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(Duration(milliseconds: millis));
}

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

  testWidgets('Login UI renders and toggles password visibility', (tester) async {
    await tester.pumpWidget(const MyApp());
    await _pumpBriefly(tester);

    final loginButton = find.text('Login');
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);
    await _pumpBriefly(tester, millis: 700);

    expect(find.text('Login to RagaSpace'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);

    final passwordToggle = find.byIcon(Icons.visibility_off_outlined);
    expect(passwordToggle, findsOneWidget);

    await tester.tap(passwordToggle);
    await _pumpBriefly(tester, millis: 250);

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Navigate to register screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await _pumpBriefly(tester);

    final loginButton = find.text('Login');
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);
    await _pumpBriefly(tester, millis: 700);

    final registerLink = find.text("Don't have an account? Register now");

    await tester.ensureVisible(registerLink);
    await _pumpBriefly(tester, millis: 250);

    await tester.tap(registerLink);
    await _pumpBriefly(tester, millis: 500);

    expect(find.text('Register to RagaSpace'), findsOneWidget);
    expect(find.text('Register'), findsWidgets);
  });
}
