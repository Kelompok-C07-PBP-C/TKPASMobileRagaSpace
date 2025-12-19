part of 'package:tk2ragaspace/features/home/home_screen.dart';

typedef BookingHttpDelete = Future<http.Response> Function(Uri uri);

/// Optional override used in tests to stub the HTTP delete call.
BookingHttpDelete? bookingHttpDeleteOverride;

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
  String _sortOrder = 'Time';
  String _paymentFilter = 'Semua';
  String _categoryFilter = 'Semua';

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
        _error =
            'Tidak bisa memuat riwayat booking. Detail: $detail';
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
        title: const Text('Batalkan booking?', style: TextStyle(color: Colors.white)),
        content: const Text('Tindakan ini akan menghapus booking yang belum dibayar.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan', style: TextStyle(color: Colors.redAccent))),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking dibatalkan.')),
          );
        }
      } else {
        throw Exception('Gagal membatalkan');
      }
    } catch (e) {
      setState(() => _cancellingId = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membatalkan booking saat ini.')),
      );
    }
  }

  List<_BookingSummary> get _visibleBookings {
    Iterable<_BookingSummary> list = _bookings;
    if (_paymentFilter == 'Sudah bayar') {
      list = list.where((b) => b.hasBeenPaid);
    } else if (_paymentFilter == 'Belum bayar') {
      list = list.where((b) => !b.hasBeenPaid);
    }
    if (_categoryFilter != 'Semua') {
      final needle = _categoryFilter.toLowerCase();
      list = list.where((b) {
        final type = b.venueType.toLowerCase();
        return type == needle || type.contains(needle);
      });
    }
    final sorted = list.toList();
    if (_sortOrder == 'Soonest' || _sortOrder == 'Latest') {
      sorted.sort((a, b) {
        final cmp = a.startDate.compareTo(b.startDate);
        return _sortOrder == 'Soonest' ? cmp : -cmp;
      });
    }
    return sorted;
  }

  List<_BookingCategoryData> get _bookingCategories {
    final grouped = <String, List<String>>{};
    for (final booking in _bookings) {
      final label =
          (booking.venueType.isEmpty ? 'Lainnya' : booking.venueType).trim();
      grouped.putIfAbsent(label, () => []).add(booking.venueImageUrl);
    }
    final labels = grouped.keys.toList()..sort();
    final chips = labels
        .map(
          (label) => _BookingCategoryData(
            label: label,
            images: grouped[label] ?? const [],
          ),
        )
        .toList();
    return [
      const _BookingCategoryData(label: 'Semua', images: [], isAll: true),
      ...chips,
    ];
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
          const Positioned.fill(
            child: TwinkleOverlay(opacity: 0.22),
          ),
          const Positioned.fill(child: _StaticAuroraBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _BookingsHeader(
                  onBack: () => Navigator.of(context).pop(),
                  totalBookings: _bookings.length,
                ),
                const SizedBox(height: 12),
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _BookingFilterBar(
            sortOrder: _sortOrder,
            paymentFilter: _paymentFilter,
            categoryFilter: _categoryFilter,
            categories: _bookingCategories,
            onSortChanged: (value) =>
                setState(() => _sortOrder = value ?? 'Time'),
            onPaymentChanged: (value) =>
                setState(() => _paymentFilter = value ?? 'Semua'),
            onCategoryChanged: (value) =>
                setState(() => _categoryFilter = value ?? 'Semua'),
          ),
          const SizedBox(height: 16),
          _EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Belum ada booking',
            message:
                'Semua booking yang kamu buat akan muncul di sini dan bisa kamu akses kapan saja.',
          ),
        ],
      );
    }
    final filtered = _visibleBookings;
    if (filtered.isEmpty) {
      final message = switch (_paymentFilter) {
        'Sudah bayar' => 'Belum ada booking yang sudah dibayar.',
        'Belum bayar' => 'Semua booking masih menunggu konfirmasi.',
        _ => 'Tidak ada booking yang cocok dengan filter ini.',
      };
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _BookingFilterBar(
            sortOrder: _sortOrder,
            paymentFilter: _paymentFilter,
            categoryFilter: _categoryFilter,
            categories: _bookingCategories,
            onSortChanged: (value) =>
                setState(() => _sortOrder = value ?? 'Time'),
            onPaymentChanged: (value) =>
                setState(() => _paymentFilter = value ?? 'Semua'),
            onCategoryChanged: (value) =>
                setState(() => _categoryFilter = value ?? 'Semua'),
          ),
          const SizedBox(height: 16),
          _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Tidak ada data',
            message: message,
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BookingFilterBar(
              sortOrder: _sortOrder,
              paymentFilter: _paymentFilter,
              categoryFilter: _categoryFilter,
              categories: _bookingCategories,
              onSortChanged: (value) =>
                  setState(() => _sortOrder = value ?? 'Time'),
              onPaymentChanged: (value) =>
                  setState(() => _paymentFilter = value ?? 'Semua'),
              onCategoryChanged: (value) =>
                  setState(() => _categoryFilter = value ?? 'Semua'),
            ),
          );
        }
        final booking = filtered[index - 1];
        return Padding(
          padding: EdgeInsets.only(bottom: index == filtered.length ? 0 : 16),
          child: _BookingCard(
            booking: booking,
            onTap: () => widget.onSelectBooking(booking),
            onCancel:
                booking.hasBeenPaid ? null : () => _cancelBooking(booking),
            cancelling: _cancellingId == booking.id,
          ),
        );
      },
    );
  }
}

class _BookingsHeader extends StatelessWidget {
  const _BookingsHeader({
    required this.onBack,
    required this.totalBookings,
  });

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
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
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
  const _BookingFilterBar({
    required this.sortOrder,
    required this.paymentFilter,
    required this.categoryFilter,
    required this.categories,
    required this.onSortChanged,
    required this.onPaymentChanged,
    required this.onCategoryChanged,
  });

  final String sortOrder;
  final String paymentFilter;
  final String categoryFilter;
  final List<_BookingCategoryData> categories;
  final ValueChanged<String?> onSortChanged;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BookingIconDropdown(
                label: 'Urutkan',
                value: sortOrder,
                visuals: const {
                  'Time': _BookingDropdownVisual(
                    icon: Icons.access_time_filled_rounded,
                    color: Colors.white,
                  ),
                  'Soonest': _BookingDropdownVisual(
                    icon: Icons.schedule_rounded,
                    color: Colors.white,
                  ),
                  'Latest': _BookingDropdownVisual(
                    icon: Icons.schedule_rounded,
                    color: Colors.white70,
                  ),
                },
                items: const ['Time', 'Soonest', 'Latest'],
                onChanged: onSortChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BookingIconDropdown(
                label: 'Status',
                value: paymentFilter,
                visuals: const {
                  'Semua': _BookingDropdownVisual(
                    icon: Icons.layers_rounded,
                    color: Colors.white,
                  ),
                  'Sudah bayar': _BookingDropdownVisual(
                    icon: Icons.check_circle_rounded,
                    color: Color(0xFF37E1A4),
                  ),
                  'Belum bayar': _BookingDropdownVisual(
                    icon: Icons.pending_actions_rounded,
                    color: Color(0xFFFFBE7B),
                  ),
                },
                items: const ['Semua', 'Sudah bayar', 'Belum bayar'],
                onChanged: onPaymentChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _GlassPanel(
            radius: 26,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            overlayColor: Colors.white.withValues(alpha: 0.08),
            borderColor: Colors.white.withValues(alpha: 0.16),
            useGradient: false,
            child: SizedBox(
              height: 134,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < categories.length; i++) ...[
                    _BookingCategoryChip(
                      data: categories[i],
                      selected: categoryFilter == categories[i].label,
                      onTap: () => onCategoryChanged(categories[i].label),
                    ),
                    if (i != categories.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap, this.onCancel, this.cancelling = false});

  final _BookingSummary booking;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final paid = booking.hasBeenPaid;
    final accent = paid ? const Color(0xFF37E1A4) : const Color(0xFFFFBE7B);
    final statusLabel = paid ? 'Paid' : 'Menunggu pembayaran';
    final dateRange = _formatBookingDateTimeRange(
      booking.startDate,
      booking.endDate,
    );
    return _GlassPanel(
      radius: 30,
      padding: const EdgeInsets.all(20),
      overlayColor:
          paid ? const Color(0x1A37E1A4) : Colors.white.withValues(alpha: 0.04),
      borderColor:
          paid ? const Color(0x3337E1A4) : Colors.white.withValues(alpha: 0.28),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                Icon(Icons.schedule_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  '${booking.sessions} sesi',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                  ),
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
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.65)),
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
                      label: Text(
                        cancelling ? 'Membatalkan...' : 'Batalkan',
                      ),
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

class _BookingCategoryData {
  const _BookingCategoryData({
    required this.label,
    required this.images,
    this.isAll = false,
  });

  final String label;
  final List<String> images;
  final bool isAll;
}

class _BookingCategoryChip extends StatelessWidget {
  const _BookingCategoryChip({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _BookingCategoryData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF2CD5FF).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.14);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF1FA2FF), Color(0xFF2CD5FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(color: borderColor),
              color: selected ? null : Colors.white.withValues(alpha: 0.04),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0x331FA2FF),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _BookingCategoryPreview(
                images: data.images,
                fallbackLabel: data.label,
                showLogo: data.isAll,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 96,
            child: Text(
              data.label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCategoryPreview extends StatelessWidget {
  const _BookingCategoryPreview({
    required this.images,
    required this.fallbackLabel,
    this.showLogo = false,
  });

  final List<String> images;
  final String fallbackLabel;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    if (showLogo) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C4BFF), Color(0xFF34B3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6DDCFF), Color(0xFF7F60F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.sports_kabaddi_rounded, color: Colors.white),
          ),
        ),
      );
    }

    if (images.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            fallbackLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final display = images.where((url) => url.isNotEmpty).take(4).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        final size = constraints.biggest;
        if (display.length == 1) {
          children.add(Positioned.fill(
            child: _buildNetworkImage(display.first, fit: BoxFit.cover),
          ));
        } else if (display.length == 2) {
          final halfHeight = size.height / 2;
          for (var i = 0; i < 2; i++) {
            children.add(Positioned(
              top: i * halfHeight,
              left: 0,
              right: 0,
              height: halfHeight,
              child: _buildNetworkImage(display[i], fit: BoxFit.cover),
            ));
          }
        } else {
          final half = size.width / 2;
          for (var i = 0; i < display.length; i++) {
            final row = i < 2 ? 0 : 1;
            final col = i % 2;
            children.add(Positioned(
              left: col * half,
              top: row * half,
              width: half,
              height: half,
              child: _buildNetworkImage(display[i], fit: BoxFit.cover),
            ));
          }
        }
        return Stack(children: children);
      },
    );
  }
}

String _formatBookingDateTimeRange(DateTime start, DateTime end) {
  final sameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) {
    return '${_formatReadableDate(start)} • ${_formatTimeCompact(start)} - ${_formatTimeCompact(end)}';
  }
  return '${_formatReadableDate(start)} ${_formatTimeCompact(start)} - ${_formatReadableDate(end)} ${_formatTimeCompact(end)}';
}

String _formatTimeCompact(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

class _BookingDropdownVisual {
  const _BookingDropdownVisual({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}

class _BookingIconDropdown extends StatelessWidget {
  const _BookingIconDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.visuals,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final Map<String, _BookingDropdownVisual> visuals;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.plusJakartaSans(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
    final visual = visuals[value] ?? visuals[label] ?? visuals.values.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: Colors.white),
          dropdownColor: const Color(0xFF0F1D3C),
          onChanged: onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(
                        visuals[item]?.icon ?? visual.icon,
                        color: visuals[item]?.color ?? visual.color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item,
                        style: labelStyle,
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (_) {
            return items
                .map(
                  (item) => Row(
                    children: [
                      Icon(
                        visual.icon,
                        color: visual.color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        value,
                        style: labelStyle,
                      ),
                    ],
                  ),
                )
                .toList();
          },
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF1FA2FF), Color(0xFF4BE2C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1FA2FF).withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
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







