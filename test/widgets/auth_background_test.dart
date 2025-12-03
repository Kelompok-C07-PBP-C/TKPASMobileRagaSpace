import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco/widgets/auth_background.dart';

void main() {
  testWidgets('AuthBackground wraps child with aurora layers',
      (tester) async {
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

  testWidgets('EdgeWave builds both normal and flipped variants',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EdgeWave(),
              EdgeWave(flip: true),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(EdgeWave), findsNWidgets(2));
  });
}

