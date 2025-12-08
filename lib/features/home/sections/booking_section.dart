part of 'package:tk2ragaspace/features/home/home_screen.dart';
// ignore_for_file: unused_element, unused_element_parameter

class _BookedDateRange {
  const _BookedDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static _BookedDateRange? tryParse(Map<String, dynamic> map) {
    DateTime? parse(String key) {
      final raw = map[key];
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) return null;
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    final startRaw = parse('start_date');
    final endRaw = parse('end_date');
    if (startRaw == null || endRaw == null) return null;
    var normalizedStart = startRaw;
    var normalizedEnd = endRaw;
    if (!normalizedEnd.isAfter(normalizedStart)) {
      return null;
    }
    return _BookedDateRange(start: normalizedStart, end: normalizedEnd);
  }

  bool overlaps(DateTime otherStart, DateTime otherEnd) {
    // Treat ranges as half-open [start, end): end is exclusive.
    final candidateStart =
        otherStart.isBefore(otherEnd) ? otherStart : otherEnd;
    final candidateEnd =
        otherStart.isBefore(otherEnd) ? otherEnd : otherStart;
    // No overlap if candidate ends on/before this.start,
    // or starts on/after this.end.
    if (candidateEnd.isBefore(start) ||
        candidateEnd.isAtSameMomentAs(start)) {
      return false;
    }
    if (candidateStart.isAfter(end) ||
        candidateStart.isAtSameMomentAs(end)) {
      return false;
    }
    return true;
  }

  Iterable<DateTime> days() sync* {
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  bool coversDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final startsBefore = !start.isAfter(dayStart);
    final endsAfter = !end.isBefore(dayEnd);
    return startsBefore && endsAfter;
  }
}

class _HourDropdownField extends StatelessWidget {
  const _HourDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.hint,
    this.dense = false,
    this.maxLines = 1,
  });

  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;
  final String hint;
  final bool dense;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final disabled = options.isEmpty;
    final gap = dense ? 4.0 : 6.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
        SizedBox(height: gap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: disabled ? null : value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F1D3C),
              icon: const Icon(Icons.expand_more, color: Colors.white70),
              selectedItemBuilder: (context) {
                return options.map((hour) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatHourLabel(hour),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList();
              },
              hint: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hint,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                  ),
                ),
              ),
              onChanged: disabled ? null : onChanged,
              items: options
                  .map(
                    (hour) => DropdownMenuItem(
                      value: hour,
                      child: Text(
                        _formatHourLabel(hour),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatHourLabel(int hour) {
  if (hour >= 24) {
    return '00:00 (besok)';
  }
  return '${hour.toString().padLeft(2, '0')}:00';
}

class _DailyHourRange {
  const _DailyHourRange({required this.startHour, required this.endHour});

  final double startHour;
  final double endHour;

  bool overlaps(double otherStart, double otherEnd) {
    // Half-open [startHour, endHour) vs [otherStart, otherEnd):
    // they overlap only when each starts before the other ends.
    return endHour > otherStart && startHour < otherEnd;
  }
}

int _dayKeyFromDate(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

class _BookingSummary {
  const _BookingSummary({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.venueType,
    required this.venueLocation,
    required this.venueDescription,
    required this.venueImageUrl,
    required this.venueImageAbsoluteUrl,
    required this.venuePrice,
    required this.startDate,
    required this.endDate,
    required this.sessions,
    required this.subtotal,
    required this.phoneNumber,
    required this.hasBeenPaid,
    required this.datePaid,
    required this.createdAt,
    required this.selectedAddons,
    required this.addonsTotal,
    required this.venueAddons,
    this.notes,
  });

  factory _BookingSummary.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? value) {
      final parsed = DateTime.tryParse(value ?? '');
      if (parsed == null) return DateTime.now();
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    final venue = (json['venue'] as Map<String, dynamic>?) ?? const {};
    final rawImageUrl =
        (venue['image_absolute_url'] ?? venue['image_url'] ?? '').toString();
    final resolvedImageUrl = _resolveMediaUrlGlobal(rawImageUrl);
    final selectedAddons = (json['selected_addons'] is List)
        ? (json['selected_addons'] as List)
            .whereType<Map<String, dynamic>>()
            .map(_VenueAddon.fromMap)
            .toList()
        : const <_VenueAddon>[];
    final venueAddons = _VenueCardData._parseAddons(venue['addons']);
    final addonsTotal =
        (json['addons_total'] as num?)?.toInt() ??
        selectedAddons.fold<int>(0, (sum, addon) => sum + addon.price);
    return _BookingSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      venueId: (venue['id'] as num?)?.toInt() ?? 0,
      venueName: (venue['title'] ?? 'Venue').toString(),
      venueType: (venue['type'] ?? '').toString(),
      venueLocation: (venue['location'] ?? '').toString(),
      venueDescription: (venue['description'] ?? '').toString(),
      venueImageUrl: resolvedImageUrl,
      venueImageAbsoluteUrl: resolvedImageUrl,
      venuePrice: (venue['price'] as num?)?.toInt() ?? 0,
      startDate: parseDate(json['start_date']?.toString()),
      endDate: parseDate(json['end_date']?.toString()),
      sessions: (json['sessions'] as num?)?.toInt() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      phoneNumber: (json['contact_phone'] ?? '').toString(),
      hasBeenPaid: json['has_been_paid'] == true,
      datePaid: json['date_paid'] == null
          ? null
          : parseDate(json['date_paid']?.toString()),
      createdAt: parseDate(json['created_at']?.toString()),
      selectedAddons: selectedAddons,
      addonsTotal: addonsTotal,
      venueAddons: venueAddons,
      notes: json['notes']?.toString(),
    );
  }

  factory _BookingSummary.localMock({
    required String venueName,
    required int venuePrice,
    required DateTime startDate,
    required DateTime endDate,
    required String phoneNumber,
    List<_VenueAddon> selectedAddons = const [],
  }) {
    final diff = endDate.difference(startDate);
    final sessions = diff.inHours <= 0 ? 1 : diff.inHours;
    final now = DateTime.now();
    return _BookingSummary(
      id: now.millisecondsSinceEpoch,
      venueId: 0,
      venueName: venueName,
      venueType: 'Venue',
      venueLocation: 'Jakarta, Indonesia',
      venueDescription: 'Booking simulasi untuk $venueName.',
      venueImageUrl: '',
      venueImageAbsoluteUrl: '',
      venuePrice: venuePrice,
      startDate: startDate,
      endDate: endDate,
      sessions: sessions,
      subtotal: sessions * venuePrice +
          selectedAddons.fold(0, (sum, addon) => sum + addon.price),
      phoneNumber: phoneNumber,
      hasBeenPaid: false,
      datePaid: null,
      createdAt: now,
      selectedAddons: selectedAddons,
      addonsTotal:
          selectedAddons.fold(0, (sum, addon) => sum + addon.price),
      venueAddons: const [],
      notes: 'Booking demo tanpa backend',
    );
  }

  final int id;
  final int venueId;
  final String venueName;
  final String venueType;
  final String venueLocation;
  final String venueDescription;
  final String venueImageUrl;
  final String venueImageAbsoluteUrl;
  final int venuePrice;
  final DateTime startDate;
  final DateTime endDate;
  final int sessions;
  final int subtotal;
  final String phoneNumber;
  final bool hasBeenPaid;
  final DateTime? datePaid;
  final DateTime createdAt;
  final List<_VenueAddon> selectedAddons;
  final int addonsTotal;
  final List<_VenueAddon> venueAddons;
  final String? notes;
}

String _formatPriceLabel(int price) {
  if (price <= 0) return 'Check availability';
  // Price is per hour on both mobile and admin
  return '${_formatCurrency(price)} / jam';
}

String _formatCurrency(int value) {
  if (value <= 0) return 'Rp 0';
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final needsSeparator = i != 0 && (digits.length - i) % 3 == 0;
    if (needsSeparator) buffer.write('.');
    buffer.write(digits[i]);
  }
  return 'Rp ${buffer.toString()}';
}

String _formatReadableDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  return '$day $month ${date.year}';
}

@visibleForTesting
_BookedDateRange? debugTryParseBookedDateRangeForTests(
        Map<String, dynamic> map) =>
    _BookedDateRange.tryParse(map);

@visibleForTesting
bool debugBookedDateRangeOverlapsForTests(
  Map<String, dynamic> map,
  DateTime otherStart,
  DateTime otherEnd,
) {
  final range = _BookedDateRange.tryParse(map);
  if (range == null) return false;
  return range.overlaps(otherStart, otherEnd);
}

@visibleForTesting
Iterable<DateTime> debugBookedDateRangeDaysForTests(
  Map<String, dynamic> map,
) {
  final range = _BookedDateRange.tryParse(map);
  return range?.days() ?? const <DateTime>[];
}

@visibleForTesting
bool debugBookedDateRangeCoversDayForTests(
  Map<String, dynamic> map,
  DateTime day,
) {
  final range = _BookedDateRange.tryParse(map);
  return range?.coversDay(day) ?? false;
}

@visibleForTesting
bool debugDailyHourOverlapForTests(
  double startHour,
  double endHour,
  double otherStart,
  double otherEnd,
) =>
    _DailyHourRange(startHour: startHour, endHour: endHour)
        .overlaps(otherStart, otherEnd);

@visibleForTesting
String debugFormatHourLabelForTests(int hour) => _formatHourLabel(hour);

@visibleForTesting
String debugFormatCurrencyForTests(int value) => _formatCurrency(value);

@visibleForTesting
String debugFormatPriceLabelForTests(int price) => _formatPriceLabel(price);

@visibleForTesting
String debugFormatReadableDateForTests(DateTime date) =>
    _formatReadableDate(date);

@visibleForTesting
dynamic debugBookingSummaryFromJsonForTests(Map<String, dynamic> json) =>
    _BookingSummary.fromJson(json);

@visibleForTesting
dynamic debugBookingSummaryLocalMockForTests({
  required String venueName,
  required int venuePrice,
  required DateTime startDate,
  required DateTime endDate,
  required String phoneNumber,
  List<Map<String, dynamic>> selectedAddons = const [],
}) {
  final addons = selectedAddons
      .map(
        (m) => _VenueAddon(
          name: (m['name'] ?? '').toString(),
          price: (m['price'] as num?)?.toInt() ?? 0,
          description: (m['description'] ?? '').toString(),
        ),
      )
      .toList();
  return _BookingSummary.localMock(
    venueName: venueName,
    venuePrice: venuePrice,
    startDate: startDate,
    endDate: endDate,
    phoneNumber: phoneNumber,
    selectedAddons: addons,
  );
}