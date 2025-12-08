part of 'package:tk2ragaspace/features/home/home_screen.dart';

typedef BookingHttpDelete = Future<http.Response> Function(Uri uri);

/// Optional override used in tests to stub the HTTP delete call.
BookingHttpDelete? bookingHttpDeleteOverride;

enum _BookingFilter { all, paid, pending }

class _BookingsScreen extends StatefulWidget {
  const _BookingsScreen({
    required this.loadBookings,
    required this.onSelectBooking,
  });

  final Future<List<_BookingSummary>> Function() loadBookings;
  final ValueChanged<_BookingSummary> onSelectBooking;

  @override
  State<_BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<_BookingsScreen> {
  int? _cancellingId;
  List<_BookingSummary> _bookings = [];
  bool _loading = true;
  String? _error;
  _BookingFilter _filter = _BookingFilter.all;

  @override
  void initState() {
    super.initState();
    _refreshBookings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loadBookings();
      if (!mounted) return;
      setState(() {
        _bookings = result;
        _loading = false;
      });
    } catch (err, stack) {
      // Log the full error for debugging, but surface a concise message.
      // ignore: avoid_print
      print('Bookings load failed: $err\n$stack');
      var detail = err.toString();
      if (detail.length > 160) {
        detail = detail.substring(0, 160);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Tidak bisa memuat riwayat booking. Detail: $detail';
      });
    }
  }

  Future<void> _cancelBooking(_BookingSummary booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13244E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan booking?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tindakan ini akan menghapus booking yang belum dibayar.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Batalkan',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancellingId = booking.id);
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/bookings/${booking.id}/');
      final deleteFn = bookingHttpDeleteOverride ?? http.delete;
      final res = await deleteFn(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          _bookings.removeWhere((b) => b.id == booking.id);
          _cancellingId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Booking dibatalkan.')));
        }
      } else {
        throw Exception('Gagal membatalkan');
      }
    } catch (e) {
      setState(() => _cancellingId = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membatalkan booking saat ini.'),
        ),
      );
    }
  }

  List<_BookingSummary> get _filteredBookings {
    switch (_filter) {
      case _BookingFilter.paid:
        return _bookings.where((booking) => booking.hasBeenPaid).toList();
      case _BookingFilter.pending:
        return _bookings.where((booking) => !booking.hasBeenPaid).toList();
      case _BookingFilter.all:
        return _bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.22)),
          const Positioned.fill(child: _StaticAuroraBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _BookingsHeader(
                  onBack: () => Navigator.of(context).pop(),
                  totalBookings: _bookings.length,
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _BookingFilterBar(
                    filter: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    color: Colors.white,
                    backgroundColor: const Color(0xFF13244E),
                    onRefresh: _refreshBookings,
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 160),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        children: [
          _ErrorNotice(
            title: 'Gagal memuat data',
            message: _error!,
            actionLabel: 'Coba lagi',
            onRetry: _refreshBookings,
          ),
        ],
      );
    }
    if (_bookings.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Belum ada booking',
        message:
            'Semua booking yang kamu buat akan muncul di sini dan bisa kamu akses kapan saja.',
      );
    }
    final filtered = _filteredBookings;
    if (filtered.isEmpty) {
      final message = _filter == _BookingFilter.paid
          ? 'Belum ada booking yang sudah dibayar.'
          : 'Semua booking masih menunggu konfirmasi.';
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada data',
        message: message,
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemBuilder: (context, index) {
        final booking = filtered[index];
        return _BookingCard(
          booking: booking,
          onTap: () => widget.onSelectBooking(booking),
          onCancel: booking.hasBeenPaid ? null : () => _cancelBooking(booking),
          cancelling: _cancellingId == booking.id,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemCount: filtered.length,
    );
  }
}

class _BookingsHeader extends StatelessWidget {
  const _BookingsHeader({required this.onBack, required this.totalBookings});

  final VoidCallback onBack;
  final int totalBookings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booked Venues',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$totalBookings total bookings',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingFilterBar extends StatelessWidget {
  const _BookingFilterBar({required this.filter, required this.onChanged});

  final _BookingFilter filter;
  final ValueChanged<_BookingFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <MapEntry<_BookingFilter, String>>[
      MapEntry(_BookingFilter.all, 'Semua'),
      MapEntry(_BookingFilter.paid, 'Paid'),
      MapEntry(_BookingFilter.pending, 'Belum dibayar'),
    ];
    return Wrap(
      spacing: 12,
      children: chips
          .map(
            (entry) => ChoiceChip(
              label: Text(
                entry.value,
                style: GoogleFonts.plusJakartaSans(
                  color: filter == entry.key
                      ? Colors.black
                      : Colors.black.withValues(alpha: 0.9),
                  fontWeight: filter == entry.key
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
              selected: filter == entry.key,
              onSelected: (_) => onChanged(entry.key),
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              selectedColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: filter == entry.key
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onTap,
    this.onCancel,
    this.cancelling = false,
  });

  final _BookingSummary booking;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final paid = booking.hasBeenPaid;
    final accent = paid ? const Color(0xFF37E1A4) : const Color(0xFFFFBE7B);
    final statusLabel = paid ? 'Paid' : 'Menunggu pembayaran';
    final dateRange =
        "${_formatReadableDate(booking.startDate)} \u2022 ${_formatReadableDate(booking.endDate)}";
    return _GlassPanel(
      radius: 30,
      padding: const EdgeInsets.all(20),
      overlayColor: paid
          ? const Color(0x1A37E1A4)
          : Colors.white.withValues(alpha: 0.04),
      borderColor: paid
          ? const Color(0x3337E1A4)
          : Colors.white.withValues(alpha: 0.28),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildNetworkImage(booking.venueImageUrl),
                    if (paid)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  '${booking.sessions} sesi',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.venueName,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              booking.venueLocation,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateRange,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(booking.subtotal),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ total',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (booking.selectedAddons.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Add-ons: ${booking.selectedAddons.map((addon) => addon.name).where((name) => name.isNotEmpty).join(', ')}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Lihat venue'),
                  ),
                  if (!paid && onCancel != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: cancelling ? null : onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: cancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_rounded, size: 18),
                      label: Text(cancelling ? 'Membatalkan...' : 'Batalkan'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 54),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Test-only helper to render the bookings screen in isolation.
Widget buildBookingsTestApp({
  required Future<List<Map<String, dynamic>>> Function() loadBookings,
  required Future<void> Function(dynamic booking) onSelect,
}) {
  Future<List<_BookingSummary>> mappedLoader() async {
    final items = await loadBookings();
    return items.map(_BookingSummary.fromJson).toList();
  }

  return MaterialApp(
    home: _BookingsScreen(
      loadBookings: mappedLoader,
      onSelectBooking: (booking) => onSelect(booking),
    ),
  );
}
