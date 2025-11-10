import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:marco/main.dart';

void main() {
  testWidgets('Login UI renders and toggles password visibility', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);

    final passwordToggle = find.byIcon(Icons.visibility_off_outlined);
    expect(passwordToggle, findsOneWidget);

    await tester.tap(passwordToggle);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Navigate to register screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final registerLink = find.text("Don't have an account? Sign Up");

    await tester.ensureVisible(registerLink);
    await tester.pumpAndSettle();

    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsWidgets);
    expect(find.text('Sign Up'), findsWidgets);
  });
}
