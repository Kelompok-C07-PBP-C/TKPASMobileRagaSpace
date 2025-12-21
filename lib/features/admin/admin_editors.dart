import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tk2ragaspace/features/admin/admin_widgets.dart';
import 'package:tk2ragaspace/features/admin/admin_theme.dart';
import 'package:tk2ragaspace/services/api.dart';

class AdminAddonDraft {
  AdminAddonDraft({this.name = '', this.price = 0, this.description = ''});

  String name;
  int price;
  String description;

  Map<String, Object?> toJson() => {
        'name': name.trim(),
        'price': price,
        'description': description.trim(),
      };

  static AdminAddonDraft fromMap(Map<String, dynamic> map) {
    return AdminAddonDraft(
      name: (map['name'] ?? '').toString(),
      price: adminSafeInt(map['price']),
      description: (map['description'] ?? '').toString(),
    );
  }
}

class AdminVenueEditorSheet extends StatefulWidget {
  const AdminVenueEditorSheet({super.key, this.venue});

  final Map<String, dynamic>? venue;

  @override
  State<AdminVenueEditorSheet> createState() => _AdminVenueEditorSheetState();
}

class _AdminVenueEditorSheetState extends State<AdminVenueEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _facilitiesController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  String _type = 'Tennis';
  List<AdminAddonDraft> _addons = <AdminAddonDraft>[];
  Uint8List? _imageBytes;
  String? _imageFilename;
  String _existingImageUrl = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final venue = widget.venue;
    if (venue == null) return;

    _titleController.text = (venue['title'] ?? '').toString();
    _descriptionController.text = (venue['description'] ?? '').toString();
    final facilities = venue['facilities'] is List
        ? (venue['facilities'] as List).map((e) => e.toString()).toList()
        : const <String>[];
    _facilitiesController.text = facilities.join(', ');
    _priceController.text = (venue['price'] ?? '').toString();
    _locationController.text = (venue['location'] ?? '').toString();
    _type = (venue['type'] ?? _type).toString();
    _existingImageUrl = (venue['image_absolute_url'] ?? venue['image_url'] ?? '').toString();
    final addons = venue['addons'];
    if (addons is List) {
      _addons = addons
          .whereType<Map<String, dynamic>>()
          .map(AdminAddonDraft.fromMap)
          .toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _facilitiesController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageFilename = file.name;
      });
    } catch (_) {
      // ignore picker failures
    }
  }

  void _addAddon() {
    setState(() => _addons = [..._addons, AdminAddonDraft()]);
  }

  int _venueId() => adminSafeInt(widget.venue?['id']);

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = Api();
      final payload = widget.venue == null
          ? await api.adminCreateVenue(
              title: _titleController.text.trim(),
              type: _type,
              description: _descriptionController.text.trim(),
              facilities: _facilitiesController.text.trim(),
              price: _priceController.text.trim(),
              location: _locationController.text.trim(),
              addons: _addons
                  .where((e) => e.name.trim().isNotEmpty)
                  .map((e) => e.toJson())
                  .toList(),
              imageBytes: _imageBytes,
              imageFilename: _imageFilename,
            )
          : await api.adminUpdateVenue(
              venueId: _venueId(),
              title: _titleController.text.trim(),
              type: _type,
              description: _descriptionController.text.trim(),
              facilities: _facilitiesController.text.trim(),
              price: _priceController.text.trim(),
              location: _locationController.text.trim(),
              addons: _addons
                  .where((e) => e.name.trim().isNotEmpty)
                  .map((e) => e.toJson())
                  .toList(),
              imageBytes: _imageBytes,
              imageFilename: _imageFilename,
            );

      if (!mounted) return;
      if (payload['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save failed')),
      );
      setState(() => _error = 'Save failed.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.venue != null;
    final resolvedExistingImageUrl = Api().resolveMediaUrl(_existingImageUrl);
    final hasExistingImage = resolvedExistingImageUrl.isNotEmpty;

    final selectedFilename = (_imageFilename ?? '').trim();
    final hasSelectedImage = _imageBytes != null;

    final rawExistingImage = _existingImageUrl.trim();
    final existingUri = Uri.tryParse(rawExistingImage);
    final existingLooksLikeUploadedFile = rawExistingImage.startsWith('/media/') ||
        (existingUri != null && existingUri.path.contains('/media/'));
    final existingIsLink = existingUri != null &&
        (existingUri.scheme == 'http' || existingUri.scheme == 'https') &&
        !existingLooksLikeUploadedFile;

    final imageLabel = hasSelectedImage
        ? (selectedFilename.isEmpty ? 'Selected image' : selectedFilename)
        : hasExistingImage
            ? (existingLooksLikeUploadedFile
                ? (Uri.tryParse(resolvedExistingImageUrl)?.pathSegments.last ?? 'Current image')
                : rawExistingImage)
            : '';
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AdminModalSheet(
                title: editing ? 'Edit venue' : 'Add venue',
                scrollController: scrollController,
                onClose: () {
                  if (_saving) return;
                  Navigator.of(context).pop(false);
                },
                footer: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminPalette.textPrimary,
                          side: BorderSide(color: AdminPalette.border.withValues(alpha: 0.85)),
                          backgroundColor: AdminPalette.surfaceHover,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminPalette.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                editing ? 'Save' : 'Create',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      AdminErrorBanner(message: _error!),
                      const SizedBox(height: 12),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _AdminTextField(
                            label: 'Title',
                            controller: _titleController,
                            validator: (value) => (value == null || value.trim().isEmpty)
                                ? 'Title is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _AdminDropdownField(
                            label: 'Type',
                            value: _type,
                            items: const [
                              'Tennis',
                              'Badminton',
                              'Basket',
                              'Sepak Bola',
                              'Mini Soccer',
                              'Futsal',
                              'Billiard',
                              'Tenis Meja',
                              'Volly Ball',
                            ],
                            onChanged: (value) => setState(() => _type = value),
                          ),
                          const SizedBox(height: 12),
                          _AdminTextField(
                            label: 'Description',
                            controller: _descriptionController,
                            maxLines: 3,
                            validator: (value) => (value == null || value.trim().isEmpty)
                                ? 'Description is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _AdminTextField(
                            label: 'Facilities (comma separated)',
                            controller: _facilitiesController,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _AdminTextField(
                                  label: 'Price',
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Required';
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed == null) return 'Invalid';
                                    if (parsed < 0) return 'Must be >= 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AdminTextField(
                                  label: 'Location',
                                  controller: _locationController,
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Image',
                              style: GoogleFonts.plusJakartaSans(
                                color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (hasSelectedImage || hasExistingImage) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: hasSelectedImage
                                      ? Image.memory(
                                          _imageBytes!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          resolvedExistingImageUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) => Container(
                                            width: 56,
                                            height: 56,
                                            color:
                                                AdminPalette.textSecondary.withValues(alpha: 0.08),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: AdminPalette.textSecondary
                                                  .withValues(alpha: 0.75),
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    imageLabel,
                                    maxLines: (!hasSelectedImage && existingIsLink) ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AdminPalette.textPrimary.withValues(alpha: 0.78),
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _pickImage,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(
                                (hasSelectedImage || hasExistingImage)
                                    ? 'Change image'
                                    : 'Pick image',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AdminPalette.textPrimary,
                                side:
                                    BorderSide(color: AdminPalette.border.withValues(alpha: 0.85)),
                                backgroundColor: AdminPalette.surfaceHover,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Add-ons',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AdminPalette.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _saving ? null : _addAddon,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AdminPalette.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_addons.isEmpty)
                            Text(
                              'No add-ons yet.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                              ),
                            )
                          else
                            ..._addons.asMap().entries.map((entry) {
                              final index = entry.key;
                              final addon = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AddonEditorCard(
                                  addon: addon,
                                  onRemove: _saving
                                      ? null
                                      : () => setState(() {
                                            _addons = [..._addons]..removeAt(index);
                                          }),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminBookingEditorSheet extends StatefulWidget {
  const AdminBookingEditorSheet({
    super.key,
    this.booking,
    required this.venues,
  });

  final Map<String, dynamic>? booking;
  final List<Map<String, dynamic>> venues;

  @override
  State<AdminBookingEditorSheet> createState() => _AdminBookingEditorSheetState();
}

class _AdminBookingEditorSheetState extends State<AdminBookingEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _venueLabelController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _notesController = TextEditingController();

  int? _venueId;
  DateTime? _start;
  DateTime? _end;
  bool _paid = false;
  bool _saving = false;
  String? _error;
  List<Map<String, Object?>> _selectedAddons = <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    if (booking != null) {
      _usernameController.text = (booking['username'] ?? '').toString();
      final venue = booking['venue'] is Map ? booking['venue'] as Map : const {};
      _venueId = adminSafeInt(venue['id'], fallback: 0);
      _venueLabelController.text = (venue['title'] ?? '').toString();
      _paid = booking['has_been_paid'] == true;
      _notesController.text = (booking['notes'] ?? '').toString();
      _start = DateTime.tryParse((booking['start_date'] ?? '').toString());
      _end = DateTime.tryParse((booking['end_date'] ?? '').toString());

      final addons = booking['selected_addons'];
      if (addons is List) {
        _selectedAddons = addons
            .whereType<Map<String, dynamic>>()
            .map((item) => <String, Object?>{
                  'name': (item['name'] ?? '').toString(),
                  'price': adminSafeInt(item['price']),
                  'description': (item['description'] ?? '').toString(),
                })
            .toList();
      }
    } else {
      final now = DateTime.now();
      _start = _normalizeToHour(now.add(const Duration(hours: 1)));
      _end = _normalizeToHour(now.add(const Duration(hours: 2)));
    }
    _syncDateControllers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _venueLabelController.dispose();
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedVenue {
    final id = _venueId;
    if (id == null || id <= 0) return null;
    return widget.venues.firstWhere(
      (venue) => adminSafeInt(venue['id'], fallback: -1) == id,
      orElse: () => const <String, dynamic>{},
    );
  }

  List<Map<String, dynamic>> _venueAddons() {
    final venue = _selectedVenue;
    if (venue == null || venue.isEmpty) return const [];
    final addons = venue['addons'];
    if (addons is! List) return const [];
    return addons.whereType<Map<String, dynamic>>().toList();
  }

  int _venuePrice() {
    final venue = _selectedVenue;
    if (venue == null || venue.isEmpty) return 0;
    return adminSafeInt(venue['price']);
  }

  int _addonsTotal() {
    return _selectedAddons.fold<int>(0, (sum, addon) {
      final price = addon['price'];
      if (price is int) return sum + price;
      return sum + (int.tryParse(price?.toString() ?? '') ?? 0);
    });
  }

  DateTime _normalizeToHour(DateTime value) {
    return DateTime(value.year, value.month, value.day, value.hour);
  }

  int _subtotal() {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return 0;
    final diff = end.difference(start).inMinutes / 60.0;
    final hours = math.max(1, diff.round());
    return hours * _venuePrice() + _addonsTotal();
  }

  void _syncDateControllers() {
    final start = _start;
    final end = _end;
    _startController.text =
        start == null ? '' : start.toLocal().toString().substring(0, 16);
    _endController.text =
        end == null ? '' : end.toLocal().toString().substring(0, 16);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final normalizedInitial = _normalizeToHour(initial);
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: normalizedInitial,
    );
    if (!mounted) return null;
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: normalizedInitial.hour, minute: 0),
    );
    if (!mounted) return null;
    if (time == null) return null;
    return _normalizeToHour(DateTime(date.year, date.month, date.day, time.hour));
  }

  String _addonKeyFromOption(Map<String, dynamic> addon) {
    final name = (addon['name'] ?? '').toString().trim().toLowerCase();
    final price = adminSafeInt(addon['price']);
    return '$name::$price';
  }

  String? _addonKeyFromSelection(Map<String, Object?> addon) {
    final name = (addon['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final price = adminSafeInt(addon['price']);
    return '${name.toLowerCase()}::$price';
  }

  void _addAddonRow() {
    setState(() {
      _selectedAddons = [
        ..._selectedAddons,
        <String, Object?>{'name': '', 'price': 0, 'description': ''},
      ];
    });
  }

  void _removeAddonRow(int index) {
    setState(() {
      final next = [..._selectedAddons]..removeAt(index);
      _selectedAddons = next;
    });
  }

  void _setAddonForRow(int index, String? addonKey) {
    final options = _venueAddons();
    Map<String, dynamic>? match;
    if (addonKey != null) {
      for (final addon in options) {
        if (_addonKeyFromOption(addon) == addonKey) {
          match = addon;
          break;
        }
      }
    }

    setState(() {
      final next = [..._selectedAddons];
      if (index < 0 || index >= next.length) return;
      if (match == null) {
        next[index] = <String, Object?>{'name': '', 'price': 0, 'description': ''};
      } else {
        next[index] = <String, Object?>{
          'name': (match['name'] ?? '').toString(),
          'price': adminSafeInt(match['price']),
          'description': (match['description'] ?? '').toString(),
        };
      }
      _selectedAddons = next;
    });
  }

  Future<void> _chooseUser() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AdminPalette.backgroundBase.withValues(alpha: 0.72),
      useSafeArea: true,
      builder: (_) => const _UserPickerSheet(),
    );
    if (result == null) return;
    final username = (result['username'] ?? result['email'] ?? '').toString();
    if (username.trim().isEmpty) return;
    setState(() => _usernameController.text = username);
  }

  Future<void> _chooseVenue() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AdminPalette.backgroundBase.withValues(alpha: 0.72),
      useSafeArea: true,
      builder: (_) => _VenuePickerSheet(initial: widget.venues),
    );
    if (result == null) return;
    final id = adminSafeInt(result['id'], fallback: -1);
    if (id <= 0) return;
    setState(() {
      _venueId = id;
      _venueLabelController.text = (result['title'] ?? '').toString();
      _selectedAddons = <Map<String, Object?>>[];
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_venueId == null || _venueId! <= 0) return;
    if (_start == null || _end == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = Api();
      final payload = widget.booking == null
          ? await api.adminCreateBooking(
              username: _usernameController.text.trim(),
              venueId: _venueId!,
              startDate: _start!,
              endDate: _end!,
              hasBeenPaid: _paid,
              notes: _notesController.text.trim(),
              selectedAddons: _selectedAddons,
            )
          : await api.adminUpdateBooking(
              bookingId: adminSafeInt(widget.booking?['id']),
              username: _usernameController.text.trim(),
              venueId: _venueId!,
              startDate: _start!,
              endDate: _end!,
              hasBeenPaid: _paid,
              notes: _notesController.text.trim(),
              selectedAddons: _selectedAddons,
            );

      if (!mounted) return;
      if (payload['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save failed')),
      );
      setState(() => _error = 'Save failed.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.booking != null;
    final subtotal = _subtotal();
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: AdminModalSheet(
            title: editing ? 'Edit booking' : 'Add booking',
            scrollController: scrollController,
            onClose: () {
              if (_saving) return;
              Navigator.of(context).pop(false);
            },
            footer: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminPalette.textPrimary,
                      side: BorderSide(color: AdminPalette.border.withValues(alpha: 0.85)),
                      backgroundColor: AdminPalette.surfaceHover,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminPalette.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            editing ? 'Save' : 'Create',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  AdminErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _AdminPickerField(
                        label: 'Guest username',
                        controller: _usernameController,
                        onTap: _saving ? null : _chooseUser,
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'User is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _AdminPickerField(
                        label: 'Venue',
                        controller: _venueLabelController,
                        onTap: _saving ? null : _chooseVenue,
                        validator: (_) => (_venueId == null || _venueId! <= 0)
                            ? 'Venue is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminPickerField(
                              label: 'Start date',
                              controller: _startController,
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final picked = await _pickDateTime(_start ?? DateTime.now());
                                      if (picked == null) return;
                                      setState(() => _start = picked);
                                      _syncDateControllers();
                                    },
                              validator: (_) => _start == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AdminPickerField(
                              label: 'End date',
                              controller: _endController,
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final picked = await _pickDateTime(_end ?? DateTime.now());
                                      if (picked == null) return;
                                      setState(() => _end = picked);
                                      _syncDateControllers();
                                    },
                              validator: (_) => _end == null ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: _paid,
                        onChanged: _saving ? null : (value) => setState(() => _paid = value),
                        title: Text(
                          'Has been paid',
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminPalette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF10B981),
                        activeTrackColor:
                            const Color(0xFF10B981).withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add-ons',
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional extras that appear on the booking modal.',
                        style: GoogleFonts.plusJakartaSans(
                          color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_venueId == null || _venueId! <= 0)
                        Text(
                          'Select a venue first to configure add-ons.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                          ),
                        )
                      else if (_venueAddons().isEmpty)
                        Text(
                          'This venue has no add-ons.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                          ),
                        )
                      else ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _addAddonRow,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'Add add-on',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminPalette.textPrimary,
                              side: BorderSide(color: AdminPalette.border.withValues(alpha: 0.7)),
                              backgroundColor: AdminPalette.surfaceHover.withValues(alpha: 0.6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_selectedAddons.isEmpty)
                          Text(
                            'No add-ons yet.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          ..._selectedAddons.asMap().entries.map((entry) {
                            final index = entry.key;
                            final selection = entry.value;
                            final addonKey = _addonKeyFromSelection(selection);
                            final reservedKeys = <String>{};
                            for (final addon in _selectedAddons) {
                              final key = _addonKeyFromSelection(addon);
                              if (key != null) reservedKeys.add(key);
                            }
                            if (addonKey != null) {
                              reservedKeys.remove(addonKey);
                            }
                            final price = adminSafeInt(selection['price']);
                            final description = (selection['description'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _BookingAddonCard(
                                index: index + 1,
                                value: addonKey,
                                reservedKeys: reservedKeys,
                                options: _venueAddons(),
                                optionKey: _addonKeyFromOption,
                                onChanged: _saving ? null : (value) => _setAddonForRow(index, value),
                                onRemove: _saving ? null : () => _removeAddonRow(index),
                                price: price,
                                description: description,
                              ),
                            );
                          }),
                      ],
                      const SizedBox(height: 12),
                      _AdminReadOnlyField(
                        label: 'Subtotal',
                        value: adminFormatIdr(subtotal),
                      ),
                      const SizedBox(height: 12),
                      _AdminTextField(
                        label: 'Notes',
                        controller: _notesController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet();

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await Api().adminUsersSearch(query: trimmed);
      final data = payload['data'];
      setState(() {
        _results = data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: AdminModalSheet(
            title: 'Search users',
            scrollController: scrollController,
            onClose: () => Navigator.of(context).pop(null),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  onChanged: _scheduleSearch,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminPalette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a username, name, or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  AdminErrorBanner(message: _error!)
                else if (_results.isEmpty && _controller.text.trim().isNotEmpty && !_loading)
                  Text(
                    'No users found.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  ..._results.map((user) {
                    final title =
                        (user['display_name'] ?? user['username'] ?? '').toString();
                    final subtitle = (user['email'] ?? '').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: AdminPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: subtitle.trim().isEmpty
                          ? null
                          : Text(
                              subtitle,
                              style: GoogleFonts.plusJakartaSans(
                                color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AdminPalette.textSecondary,
                      ),
                      onTap: () => Navigator.of(context).pop(user),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VenuePickerSheet extends StatefulWidget {
  const _VenuePickerSheet({required this.initial});

  final List<Map<String, dynamic>> initial;

  @override
  State<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends State<_VenuePickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];

  @override
  void initState() {
    super.initState();
    _results = widget.initial;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = widget.initial;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await Api().adminVenuesList(
        query: trimmed,
        page: 1,
        pageSize: 30,
      );
      final data = payload['data'];
      setState(() {
        _results = data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: AdminModalSheet(
            title: 'Search venues',
            scrollController: scrollController,
            onClose: () => Navigator.of(context).pop(null),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  onChanged: _scheduleSearch,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminPalette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a venue title or location',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  AdminErrorBanner(message: _error!)
                else if (_results.isEmpty && _controller.text.trim().isNotEmpty && !_loading)
                  Text(
                    'No venues found.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  ..._results.map((venue) {
                    final title = (venue['title'] ?? '').toString();
                    final subtitle = (venue['location'] ?? '').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: AdminPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: subtitle.trim().isEmpty
                          ? null
                          : Text(
                              subtitle,
                              style: GoogleFonts.plusJakartaSans(
                                color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AdminPalette.textSecondary,
                      ),
                      onTap: () => Navigator.of(context).pop(venue),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddonEditorCard extends StatelessWidget {
  const _AddonEditorCard({required this.addon, required this.onRemove});

  final AdminAddonDraft addon;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      tint: AdminPalette.surfaceCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Addon',
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: AdminPalette.textSecondary.withValues(alpha: 0.85),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: addon.name,
            onChanged: (value) => addon.name = value,
            style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
            decoration: _adminInputDecoration('Name'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: addon.price <= 0 ? '' : addon.price.toString(),
            onChanged: (value) => addon.price = int.tryParse(value.trim()) ?? 0,
            style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
            keyboardType: TextInputType.number,
            decoration: _adminInputDecoration('Price'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: addon.description,
            onChanged: (value) => addon.description = value,
            style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
            maxLines: 2,
            decoration: _adminInputDecoration('Description'),
          ),
        ],
      ),
    );
  }
}

class _BookingAddonCard extends StatelessWidget {
  const _BookingAddonCard({
    required this.index,
    required this.value,
    required this.reservedKeys,
    required this.options,
    required this.optionKey,
    required this.onChanged,
    required this.onRemove,
    required this.price,
    required this.description,
  });

  final int index;
  final String? value;
  final Set<String> reservedKeys;
  final List<Map<String, dynamic>> options;
  final String Function(Map<String, dynamic>) optionKey;
  final ValueChanged<String?>? onChanged;
  final VoidCallback? onRemove;
  final int price;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AdminPalette.surfaceCard.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AdminPalette.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Addon #$index',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminPalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                tooltip: 'Remove add-on',
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue:
                value != null && options.any((addon) => optionKey(addon) == value) ? value : null,
            onChanged: onChanged,
            isExpanded: true,
            hint: Text(
              'Choose an add-on',
              style: GoogleFonts.plusJakartaSans(
                color: AdminPalette.textSecondary.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            decoration: _adminInputDecoration('Add-on name'),
            dropdownColor: AdminPalette.backgroundBase,
            icon: const Icon(Icons.expand_more_rounded),
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            items: [
              for (final addon in options)
                if (!reservedKeys.contains(optionKey(addon)))
                DropdownMenuItem<String>(
                  value: optionKey(addon),
                  child: Text((addon['name'] ?? '').toString()),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _AdminReadonlyTextField(
            label: 'Price',
            value: price <= 0 ? '' : adminFormatIdr(price),
          ),
          const SizedBox(height: 12),
          _AdminReadonlyTextField(
            label: 'Description',
            value: description,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

InputDecoration _adminInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.plusJakartaSans(
      color: AdminPalette.textSecondary.withValues(alpha: 0.85),
    ),
    filled: true,
    fillColor: AdminPalette.inputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AdminPalette.border.withValues(alpha: 0.85)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AdminPalette.border.withValues(alpha: 0.85)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AdminPalette.accent, width: 1.2),
    ),
  );
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _adminInputDecoration(label),
    );
  }
}

class _AdminDropdownField extends StatelessWidget {
  const _AdminDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      key: ValueKey(resolvedValue),
      initialValue: resolvedValue,
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
      dropdownColor: const Color(0xFF050816),
      decoration: _adminInputDecoration(label),
      iconEnabledColor: AdminPalette.textSecondary.withValues(alpha: 0.85),
      style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
    );
  }
}

class _AdminPickerField extends StatelessWidget {
  const _AdminPickerField({
    required this.label,
    required this.controller,
    required this.onTap,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      validator: validator,
      onTap: onTap,
      style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
      decoration: _adminInputDecoration(label).copyWith(
        suffixIcon: const Icon(Icons.expand_more_rounded),
        suffixIconColor: AdminPalette.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }
}

class _AdminReadOnlyField extends StatelessWidget {
  const _AdminReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      key: ValueKey<String>('readonly:$label:$value'),
      decoration: _adminInputDecoration(label),
      child: Text(
        value,
        style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
      ),
    );
  }
}

class _AdminReadonlyTextField extends StatelessWidget {
  const _AdminReadonlyTextField({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey<String>('readonly:$label:$value:$maxLines'),
      readOnly: true,
      initialValue: value,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
      decoration: _adminInputDecoration(label),
    );
  }
}
