import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/home/home_screen.dart';

void main() {
  testWidgets(
      '_VenueDetailLoadingScreen shows loader then navigates to detail screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(child: _LoadingHost()),
        ),
      ),
    );

    // Initial state: loading screen content is visible.
    expect(find.textContaining('Opening Test Venue'), findsOneWidget);

    // Advance time past the 2400ms delay used in _navigateToDetail.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // After navigation, the VenueDetailScreen should be present.
    final detailFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_VenueDetailScreen',
    );
    expect(detailFinder, findsOneWidget);
  });
}

/// Small wrapper that uses the test helper so we don't rely on private types.
class _LoadingHost extends StatelessWidget {
  const _LoadingHost();

  @override
  Widget build(BuildContext context) {
    return buildVenueLoadingTestShell();
  }
}

