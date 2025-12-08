import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tk2ragaspace/main.dart';

Future<void> _pumpBriefly(WidgetTester tester, {int millis = 400}) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(Duration(milliseconds: millis));
}

void main() {
  testWidgets('Login UI renders and toggles password visibility', (tester) async {
    await tester.pumpWidget(const MyApp());
    await _pumpBriefly(tester);

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);

    final passwordToggle = find.byIcon(Icons.visibility_off_outlined);
    expect(passwordToggle, findsOneWidget);

    await tester.tap(passwordToggle);
    await _pumpBriefly(tester, millis: 250);

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Navigate to register screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await _pumpBriefly(tester);

    final registerLink = find.text("Don't have an account? Sign Up");

    await tester.ensureVisible(registerLink);
    await _pumpBriefly(tester, millis: 250);

    await tester.tap(registerLink);
    await _pumpBriefly(tester, millis: 500);

    expect(find.text('Register'), findsWidgets);
    expect(find.text('Sign Up'), findsWidgets);
  });
}
