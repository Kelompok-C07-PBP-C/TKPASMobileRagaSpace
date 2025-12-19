part of 'package:tk2ragaspace/features/home/home_screen.dart';

class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, padding.top + 16, 16, padding.bottom + 16),
          child: child,
        ),
      ),
    );
  }
}

@visibleForTesting
bool bookingDialogFailNextSubmitForTests = false;

@visibleForTesting
bool bookingDialogSkipNavigatorPopForTests = false;

@visibleForTesting
typedef BookingDatePickerOverride = Future<DateTime?> Function(
  BuildContext context,
  DateTime initialDate,
  DateTime firstDate,
  DateTime lastDate,
);

@visibleForTesting
BookingDatePickerOverride? bookingStartDatePickerOverrideForTests;

@visibleForTesting
BookingDatePickerOverride? bookingEndDatePickerOverrideForTests;

@visibleForTesting
Widget buildBookingDialogTestShell() {
  final disabledDays = <int>{
    _dayKeyFromDate(DateTime(2025, 1, 5)),
  };
  final sampleRange = _BookedDateRange(
    start: DateTime(2025, 1, 10, 9),
    end: DateTime(2025, 1, 10, 11),
  );
  final sampleDayKey = _dayKeyFromDate(DateTime(2025, 1, 10));
  final sampleDailyBlocks = <int, List<_DailyHourRange>>{
    sampleDayKey: const [
      _DailyHourRange(startHour: 9, endHour: 11),
    ],
  };

  return _DialogShell(
    child: _BookingDialog(
      pricePerSession: 100000,
      venueName: 'Test Venue',
      disabledDayKeys: disabledDays,
      selectedAddons: const <_VenueAddon>[
        _VenueAddon(
          name: 'Massage',
          price: 50000,
          description: 'Test add-on',
        ),
      ],
      onSubmit: (start, end, phone, addons) async {
        if (bookingDialogFailNextSubmitForTests) {
          bookingDialogFailNextSubmitForTests = false;
          throw ApiError('submit failed');
        }
        return _BookingSummary.localMock(
        venueName: 'Test Venue',
        venuePrice: 100000,
        startDate: start,
        endDate: end,
        phoneNumber: phone,
        selectedAddons: addons,
        );
      },
      bookedRanges: <_BookedDateRange>[sampleRange],
      bookedHoursByDay: sampleDailyBlocks,
      phoneNumber: '08123',
    ),
  );
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({
    required this.pricePerSession,
    required this.venueName,
    required this.disabledDayKeys,
    required this.selectedAddons,
    required this.onSubmit,
    required this.bookedRanges,
    required this.bookedHoursByDay,
    required this.phoneNumber,
  });

  final int pricePerSession;
  final String venueName;
  final Set<int> disabledDayKeys;
  final List<_VenueAddon> selectedAddons;
  final Future<_BookingSummary> Function(
    DateTime startDate,
    DateTime endDate,
    String phoneNumber,
    List<_VenueAddon> selectedAddons,
  ) onSubmit;
  final List<_BookedDateRange> bookedRanges;
  final Map<int, List<_DailyHourRange>> bookedHoursByDay;
  final String phoneNumber;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _error;
  bool _submitting = false;
  int? _startHour;
  int? _endHour;

  DateTime _normalizeDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isDateDisabled(DateTime date) =>
      widget.disabledDayKeys.contains(_dayKeyFromDate(date));

  bool _rangeOverlapsDisabled(DateTime start, DateTime end) {
    var cursor = _normalizeDate(start);
    final last = _normalizeDate(end);
    while (!cursor.isAfter(last)) {
      if (_isDateDisabled(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
    var normalized = _normalizeDate(value);
    if (normalized.isBefore(min)) normalized = min;
    if (normalized.isAfter(max)) normalized = max;
    return normalized;
  }

  DateTime? _nextSelectableDate(DateTime start, DateTime lastDate) {
    var cursor = _normalizeDate(start);
    while (!cursor.isAfter(lastDate)) {
      if (!_isDateDisabled(cursor)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  DateTime? get _startDateTime {
    if (_startDate == null || _startHour == null) return null;
    return _combineDateAndHour(_startDate!, _startHour!);
  }

  DateTime? get _endDateTime {
    if (_endDate == null || _endHour == null) return null;
    return _combineDateAndHour(_endDate!, _endHour!, isEnd: true);
  }

  DateTime _combineDateAndHour(DateTime date, int hour, {bool isEnd = false}) {
    final base = DateTime(date.year, date.month, date.day);
    if (isEnd && hour >= 24) {
      return base.add(const Duration(days: 1));
    }
    return base.add(Duration(hours: hour));
  }

  bool _isRangeAvailable(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return false;
    for (final range in widget.bookedRanges) {
      if (range.overlaps(start, end)) {
        return false;
      }
    }
    return true;
  }

  List<int> _availableStartHours() {
    final date = _startDate;
    if (date == null) return const [];
    final dayKey = _dayKeyFromDate(date);
    final blocked =
        widget.bookedHoursByDay[dayKey] ?? const <_DailyHourRange>[];
    final hours = <int>[];
    for (var hour = 0; hour < 24; hour++) {
      final slotStart = hour.toDouble();
      final slotEnd = slotStart + 1;
      final overlaps = blocked.any(
        (range) => range.overlaps(slotStart, slotEnd),
      );
      if (!overlaps) {
        hours.add(hour);
      }
    }
    return hours;
  }

  List<int> _availableEndHours() {
    final endDate = _endDate;
    final startDateTime = _startDateTime;
    final startDate = _startDate;
    if (endDate == null || startDateTime == null || startDate == null) {
      return const [];
    }
    final isSameDay = _normalizeDate(
      startDate,
    ).isAtSameMomentAs(_normalizeDate(endDate));
    final minHour = isSameDay && _startHour != null ? _startHour! + 1 : 1;
    final hours = <int>[];
    for (var hour = minHour; hour <= 24; hour++) {
      final candidateEnd = _combineDateAndHour(endDate, hour, isEnd: true);
      if (!candidateEnd.isAfter(startDateTime)) continue;
      bool overlaps = false;
      for (final range in widget.bookedRanges) {
        if (range.overlaps(startDateTime, candidateEnd)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        hours.add(hour);
      }
    }
    return hours;
  }

  int _sessionCount() {
    final start = _startDateTime;
    final end = _endDateTime;
    if (start == null || end == null) return 0;
    final diff = end.difference(start);
    final hours = diff.inMinutes / 60;
    return hours.ceil().clamp(1, 1000).toInt();
  }

  int get _selectedAddonsTotalExternal =>
      widget.selectedAddons.fold<int>(0, (sum, addon) => sum + addon.price);

  int get _estimatedSubtotal {
    final sessions = _sessionCount();
    final base = sessions * widget.pricePerSession;
    return base + _selectedAddonsTotalExternal;
  }

  int _dayKeyFromDate(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  bool _validateRange() {
    final start = _startDateTime;
    final end = _endDateTime;
    if (start == null || end == null) {
      setState(() {
        _error = 'Pilih tanggal mulai & selesai.';
      });
      return false;
    }
    if (_rangeOverlapsDisabled(start, end)) {
      setState(() {
        _error = 'Tanggal dipilih sudah penuh.';
      });
      return false;
    }
    if (!_isRangeAvailable(start, end)) {
      setState(() {
        _error = 'Rentang ini sudah terisi.';
      });
      return false;
    }
    if (end.difference(start).inHours < 1) {
      setState(() {
        _error = 'Durasi minimal 1 jam.';
      });
      return false;
    }
    setState(() {
      _error = null;
    });
    return true;
  }

  // Test-only helpers to exercise internal booking logic.
  @visibleForTesting
  DateTime debugNormalizeDate(DateTime value) => _normalizeDate(value);

  @visibleForTesting
  DateTime debugClampDate(
    DateTime value,
    DateTime min,
    DateTime max,
  ) =>
      _clampDate(value, min, max);

  @visibleForTesting
  DateTime? debugNextSelectableDate(DateTime start, DateTime lastDate) =>
      _nextSelectableDate(start, lastDate);

  @visibleForTesting
  DateTime debugCombineDateAndHour(DateTime date, int hour,
          {bool isEnd = false}) =>
      _combineDateAndHour(date, hour, isEnd: isEnd);

  @visibleForTesting
  bool debugIsRangeAvailable(DateTime start, DateTime end) =>
      _isRangeAvailable(start, end);

  @visibleForTesting
  bool debugRangeOverlapsDisabled(DateTime start, DateTime end) =>
      _rangeOverlapsDisabled(start, end);

  @visibleForTesting
  List<int> debugAvailableStartHours() => _availableStartHours();

  @visibleForTesting
  List<int> debugAvailableEndHours() => _availableEndHours();

  @visibleForTesting
  int debugDayKeyFromDate(DateTime date) => _dayKeyFromDate(date);

  @visibleForTesting
  int debugSelectedAddonsTotalExternal() => _selectedAddonsTotalExternal;

  @visibleForTesting
  int debugEstimatedSubtotal() => _estimatedSubtotal;

  @visibleForTesting
  void debugSetDates({
    DateTime? startDate,
    DateTime? endDate,
    int? startHour,
    int? endHour,
  }) {
    _startDate = startDate;
    _endDate = endDate;
    _startHour = startHour;
    _endHour = endHour;
  }

  @visibleForTesting
  int debugSessionCount() => _sessionCount();

  @visibleForTesting
  bool debugValidateRange() => _validateRange();

  @visibleForTesting
  void debugSetError(String? message) {
    _error = message;
  }

  @visibleForTesting
  Future<void> debugSubmitForTests() async => _submit();

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? _nextSelectableDate(now, now.add(const Duration(days: 365))) ?? now;
    final last = now.add(const Duration(days: 365));
    final picked = bookingStartDatePickerOverrideForTests != null
        ? await bookingStartDatePickerOverrideForTests!(
            context,
            initial,
            now,
            last,
          )
        : await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: now,
            lastDate: last,
            selectableDayPredicate: (date) => !_isDateDisabled(date),
            builder: (dialogContext, child) {
              if (child == null) return const SizedBox.shrink();
              final darkTheme = ThemeData(
                useMaterial3: true,
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF38BDF8),
                  secondary: Color(0xFF0EA5E9),
                  surface: Color(0xFF020617),
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: const Color(0xFF020617),
              );
              return Theme(data: darkTheme, child: child);
            },
          );
    if (picked == null) return;
    final normalized = _clampDate(picked, now, last);
    _startCtrl.text = _formatReadableDate(normalized);
    setState(() {
      _startDate = normalized;
      _startHour = null;
      _endHour = null;
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final first = _startDate ?? now;
    final initial = _endDate ?? first;
    final last = now.add(const Duration(days: 365));
    final picked = bookingEndDatePickerOverrideForTests != null
        ? await bookingEndDatePickerOverrideForTests!(
            context,
            initial,
            first,
            last,
          )
        : await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
            selectableDayPredicate: (date) => !_isDateDisabled(date),
            builder: (dialogContext, child) {
              if (child == null) return const SizedBox.shrink();
              final darkTheme = ThemeData(
                useMaterial3: true,
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF38BDF8),
                  secondary: Color(0xFF0EA5E9),
                  surface: Color(0xFF020617),
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: const Color(0xFF020617),
              );
              return Theme(data: darkTheme, child: child);
            },
          );
    if (picked == null) return;
    final normalized = _clampDate(picked, first, last);
    if (_rangeOverlapsDisabled(first, normalized)) {
      setState(() {
        _error = 'Tanggal dipilih sudah penuh.';
        _endDate = normalized;
        _endHour = null;
      });
      _endCtrl.text = _formatReadableDate(normalized);
      return;
    }
    setState(() {
      _endDate = normalized;
      _endHour = null;
      _error = null;
    });
    _endCtrl.text = _formatReadableDate(normalized);
  }

  void _submit() async {
    if (!_validateRange()) return;
    final start = _startDateTime!;
    final end = _endDateTime!;
    final phone = widget.phoneNumber.trim();
    final addons = List<_VenueAddon>.from(widget.selectedAddons);
    setState(() => _submitting = true);
    try {
      final summary = await widget.onSubmit(start, end, phone, addons);
      if (!mounted) return;
      if (!bookingDialogSkipNavigatorPopForTests) {
        Navigator.of(context).pop(summary);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal membuat booking. Coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Batal'),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          backgroundColor: const Color(0xFF1FA2FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Konfirmasi'),
      ),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: null,
          color: const Color(0xFF0F1A2A),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih jadwal',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatPriceLabel(widget.pricePerSession)} · ${widget.venueName}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  final startDateField = _DateField(
                    controller: _startCtrl,
                    label: 'Mulai',
                    hint: 'Pilih tanggal',
                    onTap: _pickStartDate,
                  );
                  final endDateField = _DateField(
                    controller: _endCtrl,
                    label: 'Selesai',
                    hint: 'Pilih tanggal',
                    onTap: _pickEndDate,
                  );
                  final startHourField = _buildHourPicker(
                    label: 'Jam mulai',
                    value: _startHour,
                    options: _availableStartHours(),
                    onChanged: (value) {
                      setState(() {
                        _startHour = value;
                        _endHour = null;
                      });
                    },
                  );
                  final endHourField = _buildHourPicker(
                    label: 'Jam selesai',
                    value: _endHour,
                    options: _availableEndHours(),
                    onChanged: (value) => setState(() => _endHour = value),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        startDateField,
                        const SizedBox(height: 12),
                        startHourField,
                        const SizedBox(height: 16),
                        endDateField,
                        const SizedBox(height: 12),
                        endHourField,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: startDateField),
                          const SizedBox(width: 16),
                          Expanded(child: startHourField),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: endDateField),
                          const SizedBox(width: 16),
                          Expanded(child: endHourField),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 18),
              _BookingSubtotalBanner(
                sessions: _sessionCount(),
                pricePerSession: widget.pricePerSession,
                addonsTotal: _selectedAddonsTotalExternal,
                subtotal: _estimatedSubtotal,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFFF8E8E),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourPicker({
    required String label,
    required int? value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: options.contains(value) ? value : null,
          items: options
              .map(
                (hour) => DropdownMenuItem<int>(
                  value: hour,
                  child: Text('${hour.toString().padLeft(2, '0')}:00'),
                ),
              )
              .toList(),
          onChanged: (val) => onChanged(val ?? value ?? 0),
          dropdownColor: const Color(0xFF0F2037),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
      ],
    );
  }
}

class _BookingSubtotalBanner extends StatelessWidget {
  const _BookingSubtotalBanner({
    required this.sessions,
    required this.pricePerSession,
    required this.addonsTotal,
    required this.subtotal,
  });

  final int sessions;
  final int pricePerSession;
  final int addonsTotal;
  final int subtotal;

  @override
  Widget build(BuildContext context) {
    final hasDates = sessions > 0;
    final baseDescription = hasDates
        ? '$sessions sesi × ${_formatCurrency(pricePerSession)}'
        : 'Pilih rentang tanggal untuk menghitung sesi.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subtotal',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(subtotal),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add-ons: ${_formatCurrency(addonsTotal)}\n$baseDescription',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
      ],
    );
  }
}

class _BookingConfirmationCard extends StatelessWidget {
  const _BookingConfirmationCard({required this.summary});

  final _BookingSummary summary;

  @override
  Widget build(BuildContext context) {
    final timeRange = _formatTimeRange(summary.startDate, summary.endDate);
    return _GlassPanel(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
      overlayColor: const Color(0xFF0F2037),
      useGradient: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1FA2FF), Color(0xFF6B7CFF)],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            'Booking terkirim!',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll be contacted very soon.",
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            summary.venueName,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          _ConfirmationRow(
            label: 'ID Booking',
            value: '#${summary.id.toString().padLeft(4, '0')}',
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Rentang waktu',
            value: '',
            customValue: _DateTimeRangePill(
              start: summary.startDate,
              end: summary.endDate,
              timeRange: timeRange,
            ),
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(label: 'Total sesi', value: '${summary.sessions}x'),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Status',
            value: summary.hasBeenPaid ? 'Paid' : 'Menunggu konfirmasi',
          ),
          const SizedBox(height: 8),
          _ConfirmationRow(
            label: 'Subtotal',
            value: _formatCurrency(summary.subtotal),
            emphasize: true,
          ),
          if (summary.selectedAddons.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ConfirmationRow(
              label: 'Add-ons',
              value: summary.selectedAddons
                  .map((addon) => addon.name)
                  .join(', '),
            ),
          ],
          const SizedBox(height: 8),
          _ConfirmationRow(label: 'Kontak', value: summary.phoneNumber),
          if ((summary.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _ConfirmationRow(label: 'Catatan', value: summary.notes!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: const Color(0xFF1FA2FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Okay',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeRangePill extends StatelessWidget {
  const _DateTimeRangePill({
    required this.start,
    required this.end,
    required this.timeRange,
  });

  final DateTime start;
  final DateTime end;
  final String timeRange;

  @override
  Widget build(BuildContext context) {
    final sameDay = _isSameDay(start, end);
    final startTime = _formatTime(start);
    final endTime = _formatTime(end);
    if (sameDay) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DateBadge(date: start),
          const SizedBox(width: 12),
          Expanded(
            child: _TimeOnlyRow(timeText: '$startTime - $endTime'),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateRangeBadge(start: start, end: end),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TimeOnlyRow(timeText: startTime),
            const SizedBox(height: 10),
            _TimeOnlyRow(timeText: endTime),
          ],
        ),
      ],
    );
  }
}

String _formatTimeRange(DateTime start, DateTime end) =>
    '${_formatTime(start)} - ${_formatTime(end)}';

String _formatTime(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthLabel(DateTime value) {
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
  return months[value.month - 1];
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _monthLabel(date);
    final year = date.year.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            month,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            year,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeBadge extends StatelessWidget {
  const _DateRangeBadge({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DateBadge(date: start),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '−',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _DateBadge(date: end),
        ],
      ),
    );
  }
}

class _TimeOnlyRow extends StatelessWidget {
  const _TimeOnlyRow({required this.timeText});

  final String timeText;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFF78A7FF)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  timeText,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.customValue,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          )
        : GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.85),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: customValue ??
              Text(
                value,
                style: style,
              ),
        ),
      ],
    );
  }
}