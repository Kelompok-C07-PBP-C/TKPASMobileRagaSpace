part of 'package:tk2ragaspace/features/home/home_screen.dart';

@visibleForTesting
typedef VenueDetailHttpGet = Future<http.Response> Function(Uri uri);

@visibleForTesting
typedef VenueDetailHttpPost =
    Future<http.Response> Function(
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });

@visibleForTesting
VenueDetailHttpGet? venueDetailHttpGetOverride;

@visibleForTesting
VenueDetailHttpPost? venueDetailHttpPostOverride;

@visibleForTesting
bool homeDetailSkipReviewsNetworkForTests = false;

@visibleForTesting
typedef VenueReviewSubmitOverride =
    Future<http.Response> Function(
      Uri uri,
      Map<String, dynamic> body, {
      required bool isUpdate,
    });

@visibleForTesting
typedef VenueReviewDeleteOverride = Future<http.Response> Function(Uri uri);

@visibleForTesting
typedef VenueReviewsFetchOverride = Future<http.Response> Function(Uri uri);

@visibleForTesting
VenueReviewSubmitOverride? venueReviewSubmitOverride;

@visibleForTesting
VenueReviewDeleteOverride? venueReviewDeleteOverride;

@visibleForTesting
VenueReviewsFetchOverride? venueReviewsFetchOverride;

@visibleForTesting
typedef VenueAccountFetchOverride =
    Future<Map<String, dynamic>> Function(Api api, int userId);

@visibleForTesting
VenueAccountFetchOverride? venueAccountFetchOverride;

@visibleForTesting
int? venueAccountUserIdOverride;

@visibleForTesting
Widget buildVenueDetailTestShell({
  bool withVenueId = true,
  bool withPhoneNumber = true,
}) {
  final addons = <_VenueAddon>[
    const _VenueAddon(
      name: 'Massage',
      price: 50000,
      description: 'Test add-on',
    ),
    const _VenueAddon(name: 'Coach', price: 75000, description: 'Test coach'),
  ];
  final venue = _VenueCardData(
    category: 'Futsal',
    name: 'Test Venue',
    location: 'Jakarta',
    description: 'Indoor futsal court',
    price: 100000,
    rating: 4.5,
    imageUrl: '',
    id: withVenueId ? 1 : null,
    addons: addons,
  );
  return _VenueDetailScreen(
    data: venue,
    apiBaseUrl: _apiBaseUrl,
    isFavorite: false,
    onToggleFavorite: (_) async => true,
    accountPhoneNumber: withPhoneNumber ? '08123' : '',
  );
}

class _VenueDetailScreen extends StatefulWidget {
  const _VenueDetailScreen({
    required this.data,
    required this.apiBaseUrl,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.accountPhoneNumber,
  });

  final _VenueCardData data;
  final String apiBaseUrl;
  final bool isFavorite;
  final String? accountPhoneNumber;
  final Future<bool> Function(_VenueCardData data) onToggleFavorite;

  @override
  State<_VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<_VenueDetailScreen> {
  late _VenueCardData data;
  late String apiBaseUrl;
  late bool _isFavorite;
  List<_VenueReview> _reviews = const [];
  String? _accountPhoneNumber;
  bool _loadingReviews = false;
  String? _reviewsError;
  bool _submittingReview = false;
  bool _availabilityLoaded = false;
  bool _availabilityLoading = false;
  Completer<void>? _availabilityCompleter;
  Set<int> _blockedDayKeyCache = <int>{};
  List<_BookedDateRange> _bookedRanges = const [];
  Map<int, List<_DailyHourRange>> _bookedHoursByDay = const {};
  final Set<int> _detailSelectedAddonIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    data = widget.data;
    apiBaseUrl = widget.apiBaseUrl;
    _isFavorite = widget.isFavorite;
    _accountPhoneNumber = widget.accountPhoneNumber;
    _loadBookedRanges();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!homeDetailSkipReviewsNetworkForTests) {
        _fetchReviews();
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final result = await widget.onToggleFavorite(data);
    if (!mounted) return;
    setState(() => _isFavorite = result);
  }

  void _openAccountSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()))
        .then((_) => _refreshAccountPhone());
  }

  Future<void> _refreshAccountPhone() async {
    final userId = venueAccountUserIdOverride ?? Api.currentUserId;
    if (userId == null) return;
    try {
      final api = Api();
      final data = venueAccountFetchOverride != null
          ? await venueAccountFetchOverride!(api, userId)
          : await api.fetchAccount(userId);
      final phone = (data['phone_number'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _accountPhoneNumber = phone;
      });
    } catch (_) {
      // ignore refresh errors
    }
  }

  void _toggleDetailAddonSelection(int index, bool isSelected) {
    if (index < 0 || index >= data.addons.length) {
      return;
    }
    setState(() {
      if (isSelected) {
        _detailSelectedAddonIndexes.add(index);
      } else {
        _detailSelectedAddonIndexes.remove(index);
      }
    });
  }

  // ignore: unused_element
  int get _detailSelectedAddonsTotal {
    if (data.addons.isEmpty || _detailSelectedAddonIndexes.isEmpty) return 0;
    return _detailSelectedAddonIndexes.fold<int>(0, (sum, index) {
      if (index < 0 || index >= data.addons.length) return sum;
      return sum + data.addons[index].price;
    });
  }

  Map<int, List<_DailyHourRange>> _buildBookedHoursByDay(
    List<_BookedDateRange> ranges,
  ) {
    final result = <int, List<_DailyHourRange>>{};
    for (final range in ranges) {
      var dayCursor = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      while (dayCursor.isBefore(range.end)) {
        final dayStart = dayCursor;
        final dayEnd = dayStart.add(const Duration(days: 1));
        final segmentStart = range.start.isAfter(dayStart)
            ? range.start
            : dayStart;
        final segmentEnd = range.end.isBefore(dayEnd) ? range.end : dayEnd;
        if (segmentEnd.isAfter(segmentStart)) {
          final dayKey = _dayKeyFromDate(dayStart);
          final startHour = segmentStart.difference(dayStart).inMinutes / 60.0;
          final endHour = segmentEnd.difference(dayStart).inMinutes / 60.0;
          result
              .putIfAbsent(dayKey, () => <_DailyHourRange>[])
              .add(_DailyHourRange(startHour: startHour, endHour: endHour));
        }
        dayCursor = dayEnd;
      }
    }
    for (final entry in result.entries) {
      entry.value.sort((a, b) => a.startHour.compareTo(b.startHour));
    }
    return result;
  }

  Set<int> _computeBlockedDayKeys(Map<int, List<_DailyHourRange>> hourMap) {
    final blocked = <int>{};
    hourMap.forEach((dayKey, ranges) {
      if (_isDayFullyBooked(ranges)) {
        blocked.add(dayKey);
      }
    });
    return blocked;
  }

  bool _isDayFullyBooked(List<_DailyHourRange> ranges) {
    if (ranges.isEmpty) return false;
    double coverage = 0;
    for (final range in ranges) {
      if (range.startHour > coverage) {
        return false;
      }
      coverage = math.max(coverage, range.endHour);
      if (coverage >= 24) {
        return true;
      }
    }
    return coverage >= 24;
  }

  void _applyBookedRanges(
    List<_BookedDateRange> ranges, {
    bool markLoaded = false,
  }) {
    final hourMap = _buildBookedHoursByDay(ranges);
    final blockedKeys = _computeBlockedDayKeys(hourMap);
    if (mounted) {
      setState(() {
        _bookedRanges = ranges;
        _bookedHoursByDay = hourMap;
        _blockedDayKeyCache = blockedKeys;
        if (markLoaded) {
          _availabilityLoaded = true;
        }
      });
    } else {
      _bookedRanges = ranges;
      _bookedHoursByDay = hourMap;
      _blockedDayKeyCache = blockedKeys;
      if (markLoaded) {
        _availabilityLoaded = true;
      }
    }
  }

  List<_VenueAddon> get _detailSelectedAddons {
    if (data.addons.isEmpty || _detailSelectedAddonIndexes.isEmpty) {
      return const [];
    }
    return _detailSelectedAddonIndexes
        .where((index) => index >= 0 && index < data.addons.length)
        .map((index) => data.addons[index])
        .toList();
  }

  // === Test helpers (no-op in production) ===

  @visibleForTesting
  Map<int, List<_DailyHourRange>> debugBuildBookedHoursByDayForTests(
    List<_BookedDateRange> ranges,
  ) => _buildBookedHoursByDay(ranges);

  @visibleForTesting
  Set<int> debugComputeBlockedDayKeysForTests(
    Map<int, List<_DailyHourRange>> hourMap,
  ) => _computeBlockedDayKeys(hourMap);

  @visibleForTesting
  bool debugIsDayFullyBookedForTests(List<_DailyHourRange> ranges) =>
      _isDayFullyBooked(ranges);

  @visibleForTesting
  void debugApplyBookedRangesForTests(
    List<_BookedDateRange> ranges, {
    bool markLoaded = false,
  }) => _applyBookedRanges(ranges, markLoaded: markLoaded);

  @visibleForTesting
  List<_VenueAddon> debugDetailSelectedAddonsForTests() =>
      _detailSelectedAddons;

  @visibleForTesting
  void debugToggleDetailAddonSelectionForTests(int index, bool isSelected) =>
      _toggleDetailAddonSelection(index, isSelected);

  @visibleForTesting
  int debugDetailSelectedAddonsTotalForTests() => _detailSelectedAddonsTotal;

  @visibleForTesting
  Future<void> debugLoadBookedRangesForTests() => _loadBookedRanges();

  @visibleForTesting
  Map<int, List<_DailyHourRange>> debugBookedHoursFromStateForTests() =>
      _buildBookedHoursByDay(_bookedRanges);

  @visibleForTesting
  Set<int> debugBlockedDayKeysFromStateForTests() =>
      _computeBlockedDayKeys(_bookedHoursByDay);

  @visibleForTesting
  bool debugAvailabilityLoadedForTests() => _availabilityLoaded;

  @visibleForTesting
  Future<_BookingSummary> debugSubmitBookingRequestForTests(
    DateTime start,
    DateTime end,
    String phone,
    List<Object?> selectedAddons,
  ) => _submitBookingRequest(
    start,
    end,
    phone,
    selectedAddons.cast<_VenueAddon>(),
  );

  @visibleForTesting
  Future<void> debugOpenBookingDialogForTests(BuildContext context) =>
      _openBookingDialog(context);

  @visibleForTesting
  Future<_ReviewDraft?> debugShowReviewDialogForTests() => _showReviewDialog();

  @visibleForTesting
  Widget debugBuildStarSelectorForTests({required int currentRating}) =>
      _buildStarSelector(currentRating: currentRating, onChanged: (_) {});

  @visibleForTesting
  Widget debugBuildStarRowForTests(int rating) => _buildStarRow(rating);

  @visibleForTesting
  Future<void> debugOpenReviewComposerForTests() => _openReviewComposer();

  @visibleForTesting
  Future<void> debugFetchReviewsForTests() => _fetchReviews();

  @visibleForTesting
  Future<void> debugDeleteSampleReviewForTests() async {
    if (_reviews.isEmpty) {
      _reviews = [
        _VenueReview(
          id: 1,
          venueId: data.id ?? 1,
          author: 'Tester',
          comment: 'Great venue',
          rating: 4,
          date: DateTime(2025, 1, 10),
          isMine: true,
        ),
      ];
    }
    await _deleteReview(_reviews.first);
  }

  @visibleForTesting
  Future<void> debugRefreshAccountPhoneForTests() => _refreshAccountPhone();

  Future<void> _loadBookedRanges() async {
    if (_availabilityLoaded) return;
    if (_availabilityLoading) {
      await _availabilityCompleter?.future;
      return;
    }
    final venueId = data.id;
    if (venueId == null) return;
    _availabilityLoading = true;
    final completer = Completer<void>();
    _availabilityCompleter = completer;
    var success = false;
    try {
      final uri = Uri.parse('$apiBaseUrl/api/venues/$venueId/availability/');
      final response = venueDetailHttpGetOverride != null
          ? await venueDetailHttpGetOverride!(uri)
          : await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded['data']
          : decoded;
      final ranges = <_BookedDateRange>[];
      if (payload is List) {
        for (final item in payload) {
          if (item is Map<String, dynamic>) {
            final range = _BookedDateRange.tryParse(item);
            if (range != null) ranges.add(range);
          }
        }
      }
      _applyBookedRanges(ranges);
      success = true;
    } catch (_) {
      // ignore errors; booking dialog will rely on backend validation
    } finally {
      _availabilityLoading = false;
      _availabilityCompleter = null;
      _availabilityLoaded = success;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _openBookingDialog(BuildContext context) async {
    final phone = (_accountPhoneNumber ?? '').trim();
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tambahkan nomor telepon di Account settings sebelum booking.',
            ),
          ),
        );
      }
      _openAccountSettings();
      return;
    }
    await _loadBookedRanges();
    if (!context.mounted) return;
    final summary = await _showBookingDialog(context);
    if (summary == null || !context.mounted) return;
    _appendBookedRange(summary.startDate, summary.endDate);
    await _showConfirmationDialog(context, summary);
  }

  Future<_BookingSummary?> _showBookingDialog(BuildContext context) {
    return showGeneralDialog<_BookingSummary>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'booking-dialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) => _DialogShell(
        child: _BookingDialog(
          pricePerSession: data.price,
          venueName: data.name,
          disabledDayKeys: _blockedDayKeys(),
          selectedAddons: _detailSelectedAddons,
          bookedRanges: _bookedRanges,
          bookedHoursByDay: _bookedHoursByDay,
          phoneNumber: (_accountPhoneNumber ?? '').trim(),
          onSubmit: (start, end, phone, addons) =>
              _submitBookingRequest(start, end, phone, addons),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(curved),
            child: Transform.scale(
              scale: 0.92 + 0.08 * curved.value,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Set<int> _blockedDayKeys() => _blockedDayKeyCache;

  void _appendBookedRange(DateTime start, DateTime end) {
    var normalizedStart = start;
    var normalizedEnd = end;
    if (normalizedEnd.isBefore(normalizedStart)) {
      final temp = normalizedStart;
      normalizedStart = normalizedEnd;
      normalizedEnd = temp;
    }
    final updatedRanges = [
      ..._bookedRanges,
      _BookedDateRange(start: normalizedStart, end: normalizedEnd),
    ];
    _applyBookedRanges(updatedRanges, markLoaded: true);
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    _BookingSummary summary,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'booking-confirmation',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 620),
      pageBuilder: (_, __, ___) =>
          _DialogShell(child: _BookingConfirmationCard(summary: summary)),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
        );
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 70),
            child: Transform.rotate(
              angle: (1 - curved.value) * 0.18,
              child: Transform.scale(
                scale: 0.8 + 0.2 * curved.value,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_BookingSummary> _submitBookingRequest(
    DateTime start,
    DateTime end,
    String phone,
    List<_VenueAddon> selectedAddons,
  ) async {
    final venueId = data.id;
    if (venueId == null) {
      return _BookingSummary.localMock(
        venueName: data.name,
        venuePrice: data.price,
        startDate: start,
        endDate: end,
        phoneNumber: phone,
        selectedAddons: selectedAddons,
      );
    }
    final uri = Uri.parse('$apiBaseUrl/api/bookings/');
    final username = Api.currentUsername;
    final payload = <String, dynamic>{
      'venue_id': venueId,
      'start_date': start.toUtc().toIso8601String(),
      'end_date': end.toUtc().toIso8601String(),
      'phone_number': phone,
      'notes': 'Booking dibuat via aplikasi mobile',
      if (selectedAddons.isNotEmpty)
        'selected_addons': selectedAddons
            .map((addon) => addon.toMap())
            .toList(),
      if (username != null && username.isNotEmpty) 'username': username,
    };
    final bodyJson = jsonEncode(payload);
    final response = venueDetailHttpPostOverride != null
        ? await venueDetailHttpPostOverride!(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: bodyJson,
          )
        : await http.post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: bodyJson,
          );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = payload['detail']?.toString();
        throw Exception(detail ?? 'Gagal membuat booking');
      } catch (_) {
        throw Exception('Gagal membuat booking');
      }
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _BookingSummary.fromJson(decoded);
  }

  @override
  Widget build(BuildContext context) {
    final background = const Color(0xFF060C18);
    // final highlight = const Color(0xFF12213D);
    final amenities = [
      'Locker rooms',
      'Premium lighting',
      'Cafe & lounge',
      'Free parking',
    ];
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _backgroundGradient),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.18)),
          const Positioned.fill(
            child: _StaticAuroraBackdrop(style: _AuroraBackdropStyle.detail),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: data.imageUrl.isNotEmpty
                                ? Image.network(
                                    data.imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: _imageFallbackGradient,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        const DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: _imageFallbackGradient,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                  )
                                : const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: _imageFallbackGradient,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pushReplacement(
                                      AuroraWarpRoute(const HomeScreen()),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.category.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    data.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _FavoriteBadgeButton(
                                  isFavorite: _isFavorite,
                                  onTap: () {
                                    _toggleFavorite();
                                    Feedback.forTap(context);
                                  },
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    data.location,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  data.rating.toStringAsFixed(1),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: _GlassPanel(
                                radius: 26,
                                // Match the subtle glass effect of the
                                // description card for a more unified look.
                                overlayColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 18,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mulai dari',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatPriceLabel(data.price),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: _GlassPanel(
                                overlayColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  data.description,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Fasilitas unggulan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: amenities
                                  .map((amenity) => _DetailChip(text: amenity))
                                  .toList(),
                            ),
                            const SizedBox(height: 32),
                            if (data.addons.isNotEmpty) ...[
                              _AddonSelectionPanel(
                                addons: data.addons,
                                selectedIndexes: _detailSelectedAddonIndexes,
                                onToggle: _toggleDetailAddonSelection,
                              ),
                              const SizedBox(height: 28),
                            ],
                            const SizedBox(height: 24),
                            _buildReviewsSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _DetailBottomBar(
        onTapBook: () => _openBookingDialog(context),
        category: data.category,
      ),
    );
  }

  Future<void> _openReviewComposer({_VenueReview? review}) async {
    final result = await _showReviewDialog(existing: review);
    if (result == null || data.id == null) return;
    setState(() => _submittingReview = true);
    try {
      final uri = review == null
          ? Uri.parse('$apiBaseUrl/api/venues/${data.id}/reviews/')
          : Uri.parse(
              '$apiBaseUrl/api/venues/${data.id}/reviews/${review.id}/',
            );
      final body = <String, dynamic>{
        'rating': result.rating,
        'comment': result.comment,
      };
      final userId = Api.currentUserId;
      final username = Api.currentUsername;
      if (userId != null) body['user_id'] = userId;
      if (username != null && username.isNotEmpty) body['username'] = username;
      Future<http.Response> send() {
        if (venueReviewSubmitOverride != null) {
          return venueReviewSubmitOverride!(
            uri,
            body,
            isUpdate: review != null,
          );
        }
        if (review == null) {
          return http
              .post(
                uri,
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 8));
        }
        return http
            .put(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      }

      final response = await send();
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        await _fetchReviews();
      } else {
        throw Exception('Failed');
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa menyimpan ulasan: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingReview = false);
      }
    }
  }

  Future<void> _deleteReview(_VenueReview review) async {
    if (data.id == null) return;
    final confirmed = await _confirmDeleteReview(review: review);
    if (!confirmed) return;
    try {
      var uri = Uri.parse(
        '$apiBaseUrl/api/venues/${data.id}/reviews/${review.id}/',
      );
      final userId = Api.currentUserId;
      if (userId != null) {
        uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'user_id': '$userId'},
        );
      }
      final res = venueReviewDeleteOverride != null
          ? await venueReviewDeleteOverride!(uri)
          : await http.delete(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          _reviews = _reviews.where((r) => r.id != review.id).toList();
        });
      } else {
        throw Exception('Failed');
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa menghapus ulasan: $err')),
      );
    }
  }

  Future<bool> _confirmDeleteReview({_VenueReview? review}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B152C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          review == null ? 'Hapus ulasan?' : 'Hapus ulasan ${review.author}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<_ReviewDraft?> _showReviewDialog({_VenueReview? existing}) {
    final controller = TextEditingController(text: existing?.comment ?? '');
    int rating = existing?.rating ?? 5;
    return showDialog<_ReviewDraft>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B152C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          existing == null ? 'Tulis ulasan' : 'Edit ulasan',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rating', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  _buildStarSelector(
                    currentRating: rating,
                    onChanged: (value) => setState(() => rating = value),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Komentar',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(
                ctx,
              ).pop(_ReviewDraft(rating: rating, comment: text));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FA2FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildStarSelector({
    required int currentRating,
    required ValueChanged<int> onChanged,
    double size = 30,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final active = index < currentRating;
        return IconButton(
          iconSize: size,
          padding: EdgeInsets.zero,
          onPressed: () => onChanged(index + 1),
          icon: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            color: active ? Colors.amber : Colors.white24,
          ),
        );
      }),
    );
  }

  Widget _buildReviewsSection() {
    final canReview = Api.currentUserId != null;
    final venueId = data.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ulasan Pengguna',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: (!canReview || venueId == null || _submittingReview)
                  ? null
                  : () => _openReviewComposer(),
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Tulis ulasan'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (_reviewsError != null)
          Text(
            _reviewsError!,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          )
        else if (_reviews.isEmpty)
          Text(
            'Belum ada ulasan untuk venue ini.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          )
        else
          Column(
            children: _reviews
                .map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ReviewCard(
                      review: review,
                      onEdit: review.isMine
                          ? () => _openReviewComposer(review: review)
                          : null,
                      onDelete: review.isMine
                          ? () => _deleteReview(review)
                          : null,
                      starBuilder: _buildStarRow,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildStarRow(int rating, {double size = 18}) {
    return Row(
      children: List.generate(5, (index) {
        final active = index < rating;
        return Icon(
          active ? Icons.star_rounded : Icons.star_border_rounded,
          color: active ? Colors.amber : Colors.white24,
          size: size,
        );
      }),
    );
  }

  Future<void> _fetchReviews() async {
    final venueId = data.id;
    if (venueId == null) return;
    setState(() {
      _loadingReviews = true;
      _reviewsError = null;
    });
    try {
      final uri = Uri.parse('$apiBaseUrl/api/venues/$venueId/reviews/');
      final res = venueReviewsFetchOverride != null
          ? await venueReviewsFetchOverride!(uri)
          : await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('Failed to load reviews');
      }
      final payload = jsonDecode(res.body) as List<dynamic>;
      final username = Api.currentUsername;
      final userId = Api.currentUserId;
      final parsed = payload
          .map(
            (raw) => _VenueReview.fromMap(
              raw as Map<String, dynamic>,
              currentUsername: username,
              currentUserId: userId,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _reviews = parsed;
        _loadingReviews = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _reviewsError = 'Tidak bisa memuat ulasan saat ini.';
        _loadingReviews = false;
      });
    }
  }
}
