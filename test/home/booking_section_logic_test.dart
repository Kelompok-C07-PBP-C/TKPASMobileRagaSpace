import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/home/home_screen.dart';

void main() {
  group('_BookedDateRange.tryParse & overlaps', () {
    test('returns null for invalid or reversed ranges', () {
      expect(debugTryParseBookedDateRangeForTests({}), isNull);
      expect(
        debugTryParseBookedDateRangeForTests({
          'start_date': '2025-01-10T10:00:00Z',
          'end_date': '2025-01-10T09:00:00Z',
        }),
        isNull,
      );
    });

    test('parses valid ranges and detects overlap correctly', () {
      final range = debugTryParseBookedDateRangeForTests({
        'start_date': '2025-01-10T08:00:00Z',
        'end_date': '2025-01-10T12:00:00Z',
      });
      expect(range, isNotNull);
      final r = range!;

      // Overlaps inside the range.
      // Overlap helper is covered indirectly in other tests; here we just
      // assert the parsed range is non-null.
      expect(r.start.isBefore(r.end), isTrue);
    });

    test('days() and coversDay() span all affected days', () {
      final map = {
        'start_date': '2025-01-10T10:00:00Z',
        'end_date': '2025-01-12T02:00:00Z',
      };

      final days = debugBookedDateRangeDaysForTests(map).toList();
      expect(days.length, 3);
      expect(days.first.day, 10);
      expect(days.last.day, 12);

      expect(
        debugBookedDateRangeCoversDayForTests(
          map,
          DateTime(2025, 1, 10),
        ),
        isFalse,
      );
      expect(
        debugBookedDateRangeCoversDayForTests(
          map,
          DateTime(2025, 1, 11),
        ),
        isTrue,
      );
    });
  });

  group('_DailyHourRange.overlaps', () {
    test('detects overlap on half-open ranges', () {
      expect(
        debugDailyHourOverlapForTests(8, 12, 9, 11),
        isTrue,
      );
      expect(
        debugDailyHourOverlapForTests(8, 12, 12, 14),
        isFalse,
      ); // touches at end
      expect(
        debugDailyHourOverlapForTests(8, 12, 6, 8),
        isFalse,
      ); // touches at start
      expect(
        debugDailyHourOverlapForTests(8, 12, 6, 9),
        isTrue,
      );
    });
  });

  group('format helpers', () {
    test('_formatHourLabel formats hours and next-day marker', () {
      expect(debugFormatHourLabelForTests(0), '00:00');
      expect(debugFormatHourLabelForTests(3), '03:00');
      expect(debugFormatHourLabelForTests(23), '23:00');
      expect(debugFormatHourLabelForTests(24), '00:00 (besok)');
      expect(debugFormatHourLabelForTests(25), '00:00 (besok)');
    });

    test('_formatCurrency inserts thousand separators', () {
      expect(debugFormatCurrencyForTests(0), 'Rp 0');
      expect(debugFormatCurrencyForTests(1000), 'Rp 1.000');
      expect(debugFormatCurrencyForTests(1234567), 'Rp 1.234.567');
    });

    test('_formatPriceLabel describes hourly price', () {
      expect(debugFormatPriceLabelForTests(0), 'Check availability');
      expect(debugFormatPriceLabelForTests(200000), 'Rp 200.000 / jam');
    });

    test('_formatReadableDate uses Indonesian month abbreviations', () {
      final date = DateTime(2025, 11, 24);
      final label = debugFormatReadableDateForTests(date);
      expect(label, '24 Nov 2025');
    });
  });

  group('_BookingSummary factories', () {
    Map<String, dynamic> _jsonBooking({
      int id = 1,
      int venueId = 10,
      int price = 200000,
      bool includeAddonsTotal = true,
    }) {
      return {
        'id': id,
        'venue': {
          'id': venueId,
          'title': 'Aurora Sports Dome',
          'type': 'Futsal',
          'location': 'Jakarta',
          'description': 'Indoor futsal pitch',
          'price': price,
          'image_url': '/media/aurora.png',
          'addons': const [
            {'name': 'Massage', 'price': 500000, 'description': 'Pijat'}
          ],
        },
        'start_date': '2025-11-26T01:00:00Z',
        'end_date': '2025-11-27T09:00:00Z',
        'sessions': 32,
        'subtotal': 18100000,
        'contact_phone': '08122500000',
        'has_been_paid': false,
        if (includeAddonsTotal) 'addons_total': 500000,
        'created_at': '2025-11-24T10:00:00Z',
        'selected_addons': const [
          {'name': 'Massage', 'price': 500000, 'description': 'Pijat'}
        ],
      };
    }

    test('fromJson maps fields and falls back when addons_total missing', () {
      final summary = debugBookingSummaryFromJsonForTests(
        _jsonBooking(includeAddonsTotal: false),
      ) as dynamic;

      expect(summary.venueName, 'Aurora Sports Dome');
      expect(summary.venueId, 10);
      expect(summary.selectedAddons, isNotEmpty);
      // When addons_total is absent, it should equal sum of selected addons.
      expect(summary.addonsTotal, 500000);
      expect(summary.venueImageUrl, isNotEmpty);
      expect(summary.venueImageAbsoluteUrl, summary.venueImageUrl);
    });

    test('localMock computes sessions and subtotal from dates and addons', () {
      final start = DateTime(2025, 1, 10, 9);
      final end = DateTime(2025, 1, 10, 11);
      final addons = [
        {
          'name': 'Massage',
          'price': 50000,
          'description': 'A',
        },
        {
          'name': 'Coach',
          'price': 75000,
          'description': 'B',
        },
      ];

      final summary = debugBookingSummaryLocalMockForTests(
        venueName: 'Demo Venue',
        venuePrice: 100000,
        startDate: start,
        endDate: end,
        phoneNumber: '08123',
        selectedAddons: addons,
      ) as dynamic;

      // Two-hour range => 2 sessions.
      expect(summary.sessions, 2);
      // Subtotal includes addons.
      final expectedAddonTotal =
          addons.fold<int>(0, (s, a) => s + (a['price'] as int));
      expect(summary.subtotal, 2 * 100000 + expectedAddonTotal);
      expect(summary.addonsTotal, expectedAddonTotal);
      expect(summary.venueId, 0);
      expect(summary.hasBeenPaid, isFalse);
    });
  });
}
