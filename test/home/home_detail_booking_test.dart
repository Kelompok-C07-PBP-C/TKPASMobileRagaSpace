import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/features/home/home_screen.dart';

void main() {
  setUp(() {
    bookingDialogSkipNavigatorPopForTests = true;
    bookingDialogFailNextSubmitForTests = false;
  });

  Future<dynamic> _pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildBookingDialogTestShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dialogFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_BookingDialog',
    );
    final dynamic state = tester.state(dialogFinder);
    return state;
  }

  testWidgets('session count, helpers, and subtotal logic are exercised',
      (tester) async {
    final state = await _pumpDialog(tester);

    final today = DateTime(2025, 1, 10);
    final tomorrow = DateTime(2025, 1, 11);

    // Normalization and clamping helpers.
    expect(state.debugNormalizeDate(tomorrow).hour, 0);
    final clamped = state.debugClampDate(
      DateTime(2024, 12, 31),
      today,
      tomorrow,
    );
    expect(clamped, today);

    // Next selectable date and day key.
    final next = state.debugNextSelectableDate(
      DateTime(2025, 1, 1),
      DateTime(2025, 1, 10),
    );
    expect(next, isNotNull);
    final dayKey = state.debugDayKeyFromDate(today);
    expect(dayKey, isNonZero);

    // Range availability and disabled check.
    final start = DateTime(2025, 1, 10, 8);
    final end = DateTime(2025, 1, 10, 12);
    expect(state.debugIsRangeAvailable(start, end), isFalse);
    expect(
      state.debugRangeOverlapsDisabled(
        DateTime(2025, 1, 5),
        DateTime(2025, 1, 6),
      ),
      isTrue,
    );

    // Available hours helpers.
    state.debugSetDates(
      startDate: today,
      endDate: today,
      startHour: 8,
      endHour: 10,
    );
    final startHours = state.debugAvailableStartHours();
    final endHours = state.debugAvailableEndHours();
    expect(startHours, isNotEmpty);
    expect(endHours, isNotEmpty);

    // Session count and subtotal helpers.
    expect(state.debugSessionCount(), greaterThan(0));
    expect(state.debugSelectedAddonsTotalExternal(), greaterThan(0));
    expect(state.debugEstimatedSubtotal(), greaterThan(0));
  });

  testWidgets('validateRange and submit cover success and error branches',
      (tester) async {
    final state = await _pumpDialog(tester);

    // No dates set.
    expect(state.debugValidateRange(), isFalse);

    final today = DateTime(2025, 1, 10);
    final tomorrow = DateTime(2025, 1, 11);

    // Range shorter than 1 hour -> invalid.
    state.debugSetDates(
      startDate: today,
      endDate: today,
      startHour: 10,
      endHour: 10,
    );
    await tester.pump();
    expect(state.debugValidateRange(), isFalse);

    // Valid one-hour range that does not overlap blocked hours.
    state.debugSetDates(
      startDate: today,
      endDate: today,
      startHour: 11,
      endHour: 12,
    );
    await tester.pump();
    expect(state.debugValidateRange(), isTrue);

    // Multi-day valid range (may overlap blocked ranges, but still exercises path).
    state.debugSetDates(
      startDate: today,
      endDate: tomorrow,
      startHour: 10,
      endHour: 11,
    );
    await tester.pump();
    state.debugValidateRange();

    // Reset to a valid one-hour range before submitting.
    state.debugSetDates(
      startDate: today,
      endDate: today,
      startHour: 11,
      endHour: 12,
    );
    await tester.pump();

    // Successful submit path (onSubmit resolves) using a fresh dialog.
    final successState = await _pumpDialog(tester);
    successState.debugSetDates(
      startDate: today,
      endDate: today,
      startHour: 11,
      endHour: 12,
    );
    await tester.pump();
    await successState.debugSubmitForTests();
    await tester.pumpAndSettle();

    // Error path: next submit fails, also using a fresh dialog.
    final errorState = await _pumpDialog(tester);
    errorState.debugSetDates(
      startDate: today,
      endDate: today,
      startHour: 11,
      endHour: 12,
    );
    await tester.pump();
    bookingDialogFailNextSubmitForTests = true;
    await errorState.debugSubmitForTests();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Gagal membuat booking'),
      findsOneWidget,
    );
  });
}
