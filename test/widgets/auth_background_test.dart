import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/widgets/auth_background.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';

void main() {
  testWidgets('AuthBackground wraps child with aurora layers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthBackground(
            child: Text('Inner content'),
          ),
        ),
      ),
    );

    expect(find.text('Inner content'), findsOneWidget);
  });

  testWidgets('AuthBackground shows twinkle overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthBackground(child: SizedBox()),
        ),
      ),
    );

    expect(find.byType(TwinkleOverlay), findsOneWidget);
  });
}
