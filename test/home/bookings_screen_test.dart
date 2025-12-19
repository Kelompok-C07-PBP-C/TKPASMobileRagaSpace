import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tk2ragaspace/features/home/home_screen.dart';

void main() {
  Map<String, dynamic> _bookingJson({
    required int id,
    required String title,
    required bool paid,
  }) {
    return {
      'id': id,
      'venue': {
        'id': id * 10,
        'title': title,
        'type': 'Futsal',
        'location': 'Jakarta',
        'description': 'Indoor futsal pitch',
        'price': 200000,
        'image_absolute_url': '',
      },
      'start_date': '2025-11-26T01:00:00Z',
      'end_date': '2025-11-27T09:00:00Z',
      'sessions': 32,
      'subtotal': 18100000,
      'contact_phone': '08122500000',
      'has_been_paid': paid,
      'created_at': '2025-11-24T10:00:00Z',
      'selected_addons': const [
        {'name': 'Pijat', 'price': 500000, 'description': 'Massage'},
      ],
    };
  }

  tearDown(() {
    bookingHttpDeleteOverride = null;
  });

  testWidgets('BookingsScreen shows loading, list, filters, and selection',
      (tester) async {
    final completer = Completer<List<Map<String, dynamic>>>();
    final selected = <dynamic>[];

    await tester.pumpWidget(
      buildBookingsTestApp(
        loadBookings: () => completer.future,
        onSelect: (booking) async => selected.add(booking),
      ),
    );

    // Initial state shows loading spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete loading with one paid and one pending booking.
    completer.complete([
      _bookingJson(id: 1, title: 'Aurora Sports Dome', paid: false),
      _bookingJson(id: 2, title: 'Harborview Badminton Center', paid: true),
    ]);
    await tester.pumpAndSettle();

    // Header and filter chips rendered.
    expect(find.text('Booked Venues'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Belum dibayar'), findsOneWidget);

    // Booking cards rendered.
    final cardFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_BookingCard',
    );
    expect(cardFinder, findsWidgets);

    // Selecting a booking via the card's onTap triggers callback.
    final firstCard = tester.widget(cardFinder.first) as dynamic;
    await tester.runAsync(() async {
      firstCard.onTap();
    });
    await tester.pumpAndSettle();
    expect(selected, isNotEmpty);

    // Change filters to exercise _BookingFilterBar and _filteredBookings logic.
    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belum dibayar'));
    await tester.pumpAndSettle();

    // Tap back button once to exercise the header onBack callback.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('BookingsScreen shows error then empty state', (tester) async {
    var attempts = 0;

    Future<List<Map<String, dynamic>>> loadBookings() async {
      attempts++;
      if (attempts == 1) {
        throw Exception('fail once');
      }
      return const [];
    }

    await tester.pumpWidget(
      buildBookingsTestApp(
        loadBookings: loadBookings,
        onSelect: (_) async {},
      ),
    );

    await tester.pumpAndSettle();

    // First attempt fails -> error notice shown.
    expect(find.text('Gagal memuat data'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    // Tap retry to trigger second load which returns empty list.
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    // Now we see the "no bookings yet" empty state.
    expect(find.text('Belum ada booking'), findsOneWidget);
  });

  testWidgets('BookingsScreen filter with no matching bookings',
      (tester) async {
    Future<List<Map<String, dynamic>>> loadPendingOnly() async => [
          _bookingJson(id: 3, title: 'Downtown Arena', paid: false),
        ];

    await tester.pumpWidget(
      buildBookingsTestApp(
        loadBookings: loadPendingOnly,
        onSelect: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    // With only a pending booking, filter "Paid" yields no data message.
    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada booking yang sudah dibayar.'),
      findsOneWidget,
    );

    // Rebuild with only a paid booking to exercise the "pending" empty message.
    Future<List<Map<String, dynamic>>> loadPaidOnly() async => [
          _bookingJson(id: 4, title: 'City Stadium', paid: true),
        ];

    await tester.pumpWidget(
      buildBookingsTestApp(
        loadBookings: loadPaidOnly,
        onSelect: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Belum dibayar'));
    await tester.pumpAndSettle();
  });

  testWidgets('BookingsScreen cancel booking success removes card',
      (tester) async {
    Future<List<Map<String, dynamic>>> loadPendingOnly() async => [
          _bookingJson(id: 3, title: 'Downtown Arena', paid: false),
        ];

    await tester.pumpWidget(
      buildBookingsTestApp(
        loadBookings: loadPendingOnly,
        onSelect: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_BookingCard',
    );
    expect(cardFinder, findsOneWidget);

    bookingHttpDeleteOverride = (uri) async => http.Response('', 204);
    final card = tester.widget(cardFinder.first) as dynamic;
    card.onCancel?.call();
    await tester.pump(); // show confirmation dialog
    final confirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Batalkan'),
    );
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(cardFinder, findsNothing);
  });

  testWidgets('BookingsScreen cancel booking failure keeps card',
      (tester) async {
    Future<List<Map<String, dynamic>>> loadPendingOnly() async => [
          _bookingJson(id: 3, title: 'Downtown Arena', paid: false),
        ];

    await tester.pumpWidget(
      buildBookingsTestApp(
        loadBookings: loadPendingOnly,
        onSelect: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    final failureCardFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_BookingCard',
    );
    expect(failureCardFinder, findsOneWidget);

    bookingHttpDeleteOverride =
        (uri) async => http.Response('error', 500); // triggers catch branch
    final failureCard = tester.widget(failureCardFinder.first) as dynamic;
    failureCard.onCancel?.call();
    await tester.pump(); // dialog
    final failureConfirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Batalkan'),
    );
    await tester.tap(failureConfirmButton);
    await tester.pumpAndSettle();

    expect(failureCardFinder, findsOneWidget);
  });
}
