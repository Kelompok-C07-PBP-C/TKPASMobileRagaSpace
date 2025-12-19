import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tk2ragaspace/features/admin/admin_editors.dart';
import 'package:tk2ragaspace/features/admin/admin_widgets.dart';
import 'package:tk2ragaspace/features/admin/admin_background.dart';
import 'package:tk2ragaspace/features/admin/admin_theme.dart';
import 'package:tk2ragaspace/features/authentication/login_screen.dart';
import 'package:tk2ragaspace/services/api.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';

enum AdminSection { venues, bookings }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final _venuesSearchController = TextEditingController();
  final _bookingsSearchController = TextEditingController();

  AdminSection _section = AdminSection.venues;

  List<Map<String, dynamic>> _venues = const [];
  Map<String, dynamic>? _venuesMeta;
  bool _venuesLoading = false;
  String? _venuesError;

  List<Map<String, dynamic>> _bookings = const [];
  Map<String, dynamic>? _bookingsMeta;
  bool _bookingsLoading = false;
  String? _bookingsError;

  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _venuesSearchController.dispose();
    _bookingsSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _bootstrapping = true);
    try {
      await Api().ensureCsrfToken();
      await Future.wait([
        _fetchVenues(resetPage: true),
        _fetchBookings(resetPage: true),
      ]);
    } finally {
      if (mounted) {
        setState(() => _bootstrapping = false);
      }
    }
  }

  int _safeInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> _fetchVenues({bool resetPage = false}) async {
    if (_venuesLoading) return;
    setState(() {
      _venuesLoading = true;
      _venuesError = null;
    });

    final currentPage =
        resetPage ? 1 : _safeInt(_venuesMeta?['page'], fallback: 1);
    try {
      final payload = await Api().adminVenuesList(
        query: _venuesSearchController.text.trim(),
        page: currentPage,
      );
      final data = payload['data'];
      final meta = payload['meta'];
      if (!mounted) return;
      setState(() {
        _venues = (data is List)
            ? data.whereType<Map<String, dynamic>>().toList()
            : const [];
        _venuesMeta = meta is Map<String, dynamic> ? meta : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _venuesError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _venuesLoading = false);
      }
    }
  }

  Future<void> _fetchBookings({bool resetPage = false}) async {
    if (_bookingsLoading) return;
    setState(() {
      _bookingsLoading = true;
      _bookingsError = null;
    });

    final currentPage =
        resetPage ? 1 : _safeInt(_bookingsMeta?['page'], fallback: 1);
    try {
      final payload = await Api().adminBookingsList(
        query: _bookingsSearchController.text.trim(),
        page: currentPage,
      );
      final data = payload['data'];
      final meta = payload['meta'];
      if (!mounted) return;
      setState(() {
        _bookings = (data is List)
            ? data.whereType<Map<String, dynamic>>().toList()
            : const [];
        _bookingsMeta = meta is Map<String, dynamic> ? meta : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookingsError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _bookingsLoading = false);
      }
    }
  }

  void _selectSection(AdminSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    Navigator.of(context).maybePop();
  }

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    // ignore: unawaited_futures
    () async {
      try {
        await Api().logout();
      } catch (_) {
        // ignored
      }
    }();
  }

  Future<void> _openVenueEditor({Map<String, dynamic>? venue}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 720),
      barrierColor: AdminPalette.backgroundBase.withValues(alpha: 0.72),
      useSafeArea: true,
      builder: (_) => AdminVenueEditorSheet(venue: venue),
    );
    if (saved == true) {
      await _fetchVenues(resetPage: true);
    }
  }

  Future<void> _openBookingEditor({Map<String, dynamic>? booking}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 720),
      barrierColor: AdminPalette.backgroundBase.withValues(alpha: 0.72),
      useSafeArea: true,
      builder: (_) => AdminBookingEditorSheet(
        booking: booking,
        venues: _venues,
      ),
    );
    if (saved == true) {
      await _fetchBookings(resetPage: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = buildAdminThemeData(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        drawer: AdminDrawer(
          section: _section,
          onSectionSelected: _selectSection,
          onLogout: _logout,
        ),
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            _section == AdminSection.venues ? 'Venues' : 'Bookings',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AdminPrimaryPillButton(
                label: _section == AdminSection.venues ? 'Add venue' : 'Add booking',
                onPressed: _bootstrapping
                    ? null
                    : () {
                        if (_section == AdminSection.venues) {
                          _openVenueEditor();
                        } else {
                          _openBookingEditor();
                        }
                      },
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: AdminBackground()),
            const Positioned.fill(child: TwinkleOverlay(opacity: 0.12)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AdminPalette.backgroundBase.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                ),
              ),
            ),
            SafeArea(
              child: _section == AdminSection.venues
                  ? AdminVenuesSection(
                      searchController: _venuesSearchController,
                      venues: _venues,
                      meta: _venuesMeta,
                      loading: _venuesLoading,
                      error: _venuesError,
                      analyticsMeta: _bookingsMeta,
                      onRefresh: () => _fetchVenues(resetPage: true),
                      onSearch: () => _fetchVenues(resetPage: true),
                      onClearSearch: () {
                        _venuesSearchController.clear();
                        _fetchVenues(resetPage: true);
                      },
                      onPreviousPage: _venuesMeta?['has_previous'] == true
                          ? () {
                              setState(() {
                                _venuesMeta = {
                                  ...?_venuesMeta,
                                  'page': _safeInt(_venuesMeta?['page'], fallback: 1) - 1,
                                };
                              });
                              _fetchVenues();
                            }
                          : null,
                      onNextPage: _venuesMeta?['has_next'] == true
                          ? () {
                              setState(() {
                                _venuesMeta = {
                                  ...?_venuesMeta,
                                  'page': _safeInt(_venuesMeta?['page'], fallback: 1) + 1,
                                };
                              });
                              _fetchVenues();
                            }
                          : null,
                      onEdit: (venue) => _openVenueEditor(venue: venue),
                      onDelete: (venue) => AdminDialogs.confirmDeleteVenue(
                        context: context,
                        venue: venue,
                        onDeleted: () => _fetchVenues(resetPage: true),
                      ),
                    )
                  : AdminBookingsSection(
                      searchController: _bookingsSearchController,
                      bookings: _bookings,
                      meta: _bookingsMeta,
                      loading: _bookingsLoading,
                      error: _bookingsError,
                      onRefresh: () => _fetchBookings(resetPage: true),
                      onSearch: () => _fetchBookings(resetPage: true),
                      onClearSearch: () {
                        _bookingsSearchController.clear();
                        _fetchBookings(resetPage: true);
                      },
                      onPreviousPage: _bookingsMeta?['has_previous'] == true
                          ? () {
                              setState(() {
                                _bookingsMeta = {
                                  ...?_bookingsMeta,
                                  'page': _safeInt(_bookingsMeta?['page'], fallback: 1) - 1,
                                };
                              });
                              _fetchBookings();
                            }
                          : null,
                      onNextPage: _bookingsMeta?['has_next'] == true
                          ? () {
                              setState(() {
                                _bookingsMeta = {
                                  ...?_bookingsMeta,
                                  'page': _safeInt(_bookingsMeta?['page'], fallback: 1) + 1,
                                };
                              });
                              _fetchBookings();
                            }
                          : null,
                      onEdit: (booking) => _openBookingEditor(booking: booking),
                      onDelete: (booking) => AdminDialogs.confirmDeleteBooking(
                        context: context,
                        booking: booking,
                        onDeleted: () => _fetchBookings(resetPage: true),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({
    super.key,
    required this.section,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final AdminSection section;
  final ValueChanged<AdminSection> onSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AdminPalette.backgroundBase.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Docs',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AdminPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Events Admin',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AdminPalette.border.withValues(alpha: 0.75), height: 1),
            const SizedBox(height: 8),
            _AdminDrawerLink(
              label: 'Venues',
              icon: Icons.storefront_outlined,
              selected: section == AdminSection.venues,
              onTap: () => onSectionSelected(AdminSection.venues),
            ),
            _AdminDrawerLink(
              label: 'Bookings',
              icon: Icons.event_available_outlined,
              selected: section == AdminSection.bookings,
              onTap: () => onSectionSelected(AdminSection.bookings),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, color: AdminPalette.danger),
                  label: Text(
                    'Log out',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: AdminPalette.danger,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AdminPalette.danger.withValues(alpha: 0.55)),
                    backgroundColor: AdminPalette.danger.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Signed in as ${Api.currentUsername ?? 'admin'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminPalette.textSecondary.withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawerLink extends StatelessWidget {
  const _AdminDrawerLink({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeGradient = LinearGradient(
      colors: [AdminPalette.accent, Color(0xFFF97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final inactiveForeground = AdminPalette.textPrimary.withValues(alpha: 0.78);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected ? activeGradient : null,
            color: selected ? null : AdminPalette.surfaceHover,
            border: Border.all(
              color: selected ? Colors.transparent : AdminPalette.border.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF0B1120) : inactiveForeground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: selected ? const Color(0xFF0B1120) : inactiveForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
