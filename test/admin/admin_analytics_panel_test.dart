import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/features/admin/admin_theme.dart';
import 'package:tk2ragaspace/features/admin/admin_widgets.dart';

void main() {
  testWidgets('AdminAnalyticsPanel lays out inside scroll views', (tester) async {
    final meta = <String, dynamic>{
      'analytics': <String, dynamic>{
        'sales': <String, dynamic>{
          'labels': <String>[
            '2025-12-15',
            '2025-12-16',
            '2025-12-17',
            '2025-12-18',
            '2025-12-19',
          ],
          'data': <num>[0, 15000, 35000, 20000, 75000],
        },
        'popularity': <String, dynamic>{
          'labels': <String>['barco', 'tennis court', 'badminton hall'],
          'data': <int>[9, 4, 2],
        },
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminThemeData(ThemeData.dark()),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AdminAnalyticsPanel(bookingsMeta: meta),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Daily sales'), findsOneWidget);
    expect(find.text('Venue popularity'), findsOneWidget);
  });
}

