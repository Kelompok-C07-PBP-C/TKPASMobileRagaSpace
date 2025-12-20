import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tk2ragaspace/features/admin/admin_theme.dart';
import 'package:tk2ragaspace/services/api.dart';

enum AdminVenueSortKey { id, title, price, rating }

extension AdminVenueSortKeyLabel on AdminVenueSortKey {
  String get label {
    switch (this) {
      case AdminVenueSortKey.id:
        return 'ID';
      case AdminVenueSortKey.title:
        return 'Title';
      case AdminVenueSortKey.price:
        return 'Price';
      case AdminVenueSortKey.rating:
        return 'Rating';
    }
  }
}

enum AdminBookingSortKey { createdAt, startDate, endDate, guest, paid }

extension AdminBookingSortKeyLabel on AdminBookingSortKey {
  String get label {
    switch (this) {
      case AdminBookingSortKey.createdAt:
        return 'Created';
      case AdminBookingSortKey.startDate:
        return 'Start date';
      case AdminBookingSortKey.endDate:
        return 'End date';
      case AdminBookingSortKey.guest:
        return 'Guest';
      case AdminBookingSortKey.paid:
        return 'Payment';
    }
  }
}

String adminFormatIdr(int value) {
  final formatted = value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );
  return 'IDR $formatted';
}

String adminFormatIdrCompact(int value) {
  if (value <= 0) return 'IDR 0';
  if (value >= 1000000000) {
    return 'IDR ${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) {
    return 'IDR ${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return 'IDR ${(value / 1000).toStringAsFixed(0)}K';
  }
  return 'IDR $value';
}

int adminSafeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

class AdminSortBar<T> extends StatelessWidget {
  const AdminSortBar({
    super.key,
    required this.options,
    required this.value,
    required this.ascending,
    required this.onChanged,
    required this.onToggleDirection,
    this.enabled = true,
    this.labelBuilder,
  });

  final List<T> options;
  final T value;
  final bool ascending;
  final ValueChanged<T> onChanged;
  final VoidCallback onToggleDirection;
  final bool enabled;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = GoogleFonts.plusJakartaSans(
      color: AdminPalette.textPrimary,
      fontWeight: FontWeight.w700,
    );

    final dropdown = DropdownButton<T>(
      value: value,
      isExpanded: true,
      dropdownColor: AdminPalette.backgroundBase,
      style: textStyle,
      iconEnabledColor: AdminPalette.textSecondary,
      onChanged: enabled
          ? (next) {
              if (next == null) return;
              onChanged(next);
            }
          : null,
      items: options
          .map(
            (option) => DropdownMenuItem<T>(
              value: option,
              child: Text(
                labelBuilder?.call(option) ?? option.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );

    final directionButton = IconButton(
      tooltip: ascending ? 'Ascending' : 'Descending',
      onPressed: enabled ? onToggleDirection : null,
      icon: Icon(
        ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: enabled
            ? AdminPalette.textPrimary.withValues(alpha: 0.85)
            : AdminPalette.textSecondary.withValues(alpha: 0.6),
      ),
    );

    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      tint: AdminPalette.surfaceCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 520;
          if (wide) {
            return Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 10),
                Text('Sort by', style: theme.textTheme.bodyMedium?.copyWith(
                  color: AdminPalette.textSecondary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AdminPalette.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AdminPalette.border.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(child: dropdown),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                directionButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sort_rounded,
                    color: AdminPalette.textSecondary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sort by',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AdminPalette.textSecondary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  directionButton,
                ],
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AdminPalette.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AdminPalette.border.withValues(alpha: 0.8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(child: dropdown),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminPrimaryPillButton extends StatelessWidget {
  const AdminPrimaryPillButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminPalette.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AdminGlassCard extends StatelessWidget {
  const AdminGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint = AdminPalette.surfaceCard,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final topTint = Color.lerp(tint, Colors.white, 0.06) ?? tint;
    final bottomTint = Color.lerp(tint, Colors.black, 0.08) ?? tint;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [topTint, bottomTint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AdminPalette.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.75),
            blurRadius: 80,
            offset: const Offset(0, 32),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AdminModalSheet extends StatelessWidget {
  const AdminModalSheet({
    super.key,
    required this.title,
    required this.scrollController,
    required this.onClose,
    required this.body,
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(22, 16, 22, 22),
  });

  final String title;
  final ScrollController scrollController;
  final VoidCallback onClose;
  final Widget body;
  final Widget? footer;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.9),
            blurRadius: 80,
            offset: const Offset(0, 32),
          ),
          BoxShadow(
            color: AdminPalette.accent.withValues(alpha: 0.25),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xF00F172A),
                        Color(0xE00F172A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.35,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AdminPalette.accent.withValues(alpha: 0.22),
                            const Color(0xFF818CF8).withValues(alpha: 0.18),
                            const Color(0xFF14B8A6).withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xD93B82F6),
                        Color(0xD9818CF8),
                        Color(0xE610B981),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: AdminPalette.border.withValues(alpha: 0.9)),
                  ),
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 16, 14, 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AdminPalette.surfaceHover,
                          Color(0x0D0F172A),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border(
                        bottom: BorderSide(color: AdminPalette.border.withValues(alpha: 0.75)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminPalette.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          color: AdminPalette.textPrimary.withValues(alpha: 0.85),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x8C0F172A),
                            Color(0xBF0F172A),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: bodyPadding,
                        children: [body],
                      ),
                    ),
                  ),
                  if (footer != null)
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x1A0F172A),
                            Color(0x590F172A),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border(
                          top: BorderSide(color: AdminPalette.border.withValues(alpha: 0.75)),
                        ),
                      ),
                      child: footer,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSearchCard extends StatelessWidget {
  const AdminSearchCard({
    super.key,
    required this.controller,
    required this.hint,
    required this.loading,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final bool loading;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      tint: AdminPalette.surfaceCard,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            enabled: !loading,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            onSubmitted: loading ? null : onSubmitted,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AdminPalette.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: AdminPalette.textSecondary),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (hasText
                      ? IconButton(
                          onPressed: onClear,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear',
                        )
                      : null),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AdminPalette.border.withValues(alpha: 0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AdminPalette.border.withValues(alpha: 0.8)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AdminPalette.border.withValues(alpha: 0.55)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AdminPalette.accent, width: 1.2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminPaginationRow extends StatelessWidget {
  const AdminPaginationRow({
    super.key,
    required this.meta,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

  final Map<String, dynamic>? meta;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final page = meta?['page'];
    final totalPages = meta?['total_pages'];
    final pageLabel =
        (page != null && totalPages != null) ? 'Page $page / $totalPages' : 'Page';

        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : onPrevious,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminPalette.textPrimary,
                  side: const BorderSide(color: AdminPalette.border),
                  backgroundColor: AdminPalette.surfaceCard,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              pageLabel,
              style: GoogleFonts.plusJakartaSans(
                color: AdminPalette.textSecondary.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : onNext,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminPalette.textPrimary,
                  side: const BorderSide(color: AdminPalette.border),
                  backgroundColor: AdminPalette.surfaceCard,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Next'),
              ),
            ),
          ],
        );
  }
}

class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      tint: Colors.redAccent.withValues(alpha: 0.14),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminLoadingCard extends StatelessWidget {
  const AdminLoadingCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionLoadingOverlay extends StatelessWidget {
  const AdminSectionLoadingOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AdminPalette.backgroundBase.withValues(alpha: 0.68),
                AdminPalette.backgroundBase.withValues(alpha: 0.42),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: AdminGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tint: AdminPalette.surfaceCard.withValues(alpha: 0.92),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminEmptyCard extends StatelessWidget {
  const AdminEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      tint: AdminPalette.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminInfoChip extends StatelessWidget {
  const AdminInfoChip({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AdminPalette.surfaceHover,
        border: Border.all(color: AdminPalette.border.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AdminPalette.textSecondary.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textSecondary.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminActionButton extends StatelessWidget {
  const AdminActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.28),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class AdminVenueCard extends StatelessWidget {
  const AdminVenueCard({
    super.key,
    required this.venue,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> venue;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = (venue['title'] ?? '').toString();
    final type = (venue['type'] ?? '').toString();
    final location = (venue['location'] ?? '').toString();
    final rawImageUrl = (venue['image_absolute_url'] ?? venue['image_url'] ?? '').toString();
    final imageUrl = Api().resolveMediaUrl(rawImageUrl);
    final price = adminSafeInt(venue['price']);
    final averageRating = venue['average_rating'];
    final ratingCount = adminSafeInt(venue['rating_count']);
    final ratingLabel =
        averageRating == null ? 'No rating' : '${averageRating.toString()} ($ratingCount)';
    final facilities = venue['facilities'] is List
        ? (venue['facilities'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      tint: AdminPalette.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 64,
                  height: 64,
                  color: AdminPalette.textSecondary.withValues(alpha: 0.08),
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.image_outlined,
                          color: AdminPalette.textSecondary.withValues(alpha: 0.75),
                        )
                      : Image.network(
                          key: ValueKey<String>(imageUrl),
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            final expected = loadingProgress.expectedTotalBytes;
                            final value = expected != null && expected > 0
                                ? loadingProgress.cumulativeBytesLoaded / expected
                                : null;
                            return Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: value,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Icon(
                            Icons.broken_image_outlined,
                            color: AdminPalette.textSecondary.withValues(alpha: 0.75),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$type • $location',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminPalette.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          ratingLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminPalette.textPrimary.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminInfoChip(
                label: adminFormatIdr(price),
                icon: Icons.payments_outlined,
              ),
              if (facilities.isNotEmpty)
                AdminInfoChip(
                  label: '${facilities.length} facilities',
                  icon: Icons.local_activity_outlined,
                ),
              AdminInfoChip(
                label: 'ID #${venue['id']}',
                icon: Icons.tag_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AdminActionButton(
                label: 'Edit',
                color: const Color(0xFF3B82F6),
                onPressed: onEdit,
              ),
              const SizedBox(width: 10),
              AdminActionButton(
                label: 'Delete',
                color: const Color(0xFFF87171),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminBookingCard extends StatelessWidget {
  const AdminBookingCard({
    super.key,
    required this.booking,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _shortIsoDate(Object? value) {
    final raw = (value ?? '').toString();
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final guest = (booking['guest_label'] ?? booking['username'] ?? '').toString();
    final venue = booking['venue'] is Map ? booking['venue'] as Map : const {};
    final venueTitle = (venue['title'] ?? '').toString();
    final phone = (booking['contact_phone'] ?? '').toString();
    final notes = (booking['notes'] ?? '').toString();
    final paid = booking['has_been_paid'] == true;
    final addonsTotal = adminSafeInt(booking['addons_total']);
    final created = _shortIsoDate(booking['created_at']);
    final start = _shortIsoDate(booking['start_date']);
    final end = _shortIsoDate(booking['end_date']);

    return AdminGlassCard(
      padding: const EdgeInsets.all(14),
      tint: AdminPalette.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  guest,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: paid
                      ? AdminPalette.success.withValues(alpha: 0.2)
                      : const Color(0xFFF97316).withValues(alpha: 0.2),
                  border: Border.all(
                    color: paid
                        ? AdminPalette.success.withValues(alpha: 0.4)
                        : const Color(0xFFF97316).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  paid ? 'Paid' : 'Pending',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: paid ? const Color(0xFFBFF7DE) : const Color(0xFFFFD1A6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            venueTitle.isEmpty ? 'Venue unavailable' : venueTitle,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminInfoChip(
                label: '$start → $end',
                icon: Icons.date_range_outlined,
              ),
              if (phone.isNotEmpty)
                AdminInfoChip(label: phone, icon: Icons.phone_outlined),
              AdminInfoChip(
                label: 'Created $created',
                icon: Icons.schedule_outlined,
              ),
              if (addonsTotal > 0)
                AdminInfoChip(
                  label: '+ ${adminFormatIdr(addonsTotal)} add-ons',
                  icon: Icons.add_circle_outline,
                ),
            ],
          ),
          if (notes.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AdminPalette.textPrimary.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AdminActionButton(
                label: 'Edit',
                color: const Color(0xFF3B82F6),
                onPressed: onEdit,
              ),
              const SizedBox(width: 10),
              AdminActionButton(
                label: 'Delete',
                color: const Color(0xFFF87171),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminAnalyticsPanel extends StatelessWidget {
  const AdminAnalyticsPanel({
    super.key,
    required this.bookingsMeta,
    this.loading = false,
  });

  final Map<String, dynamic>? bookingsMeta;
  final bool loading;

  Map<String, List<dynamic>> _extractSeries(String key) {
    final analytics = bookingsMeta?['analytics'];
    if (analytics is! Map<String, dynamic>) return const {};
    final series = analytics[key];
    if (series is! Map<String, dynamic>) return const {};
    final labels = series['labels'];
    final data = series['data'];
    if (labels is List && data is List) {
      return {'labels': labels, 'data': data};
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final showLoadingOverlay = loading;
    final sales = _extractSeries('sales');
    final popularity = _extractSeries('popularity');

    final salesLabels =
        (sales['labels'] ?? const []).map((e) => e.toString()).toList();
    final salesValues = (sales['data'] ?? const [])
        .map((e) => double.tryParse(e.toString()) ?? 0)
        .toList();

    final popularityLabels =
        (popularity['labels'] ?? const []).map((e) => e.toString()).toList();
    final popularityValues = (popularity['data'] ?? const [])
        .map((e) => adminSafeInt(e))
        .toList();

    final hasSales = salesLabels.isNotEmpty &&
        salesValues.isNotEmpty &&
        salesValues.any((value) => value > 0);
    final hasPopularity = popularityLabels.isNotEmpty &&
        popularityValues.isNotEmpty &&
        popularityValues.any((value) => value > 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final chartHeight = wide ? 330.0 : 310.0;

        final salesCard = _AdminChartCard(
          title: 'Daily sales',
          subtitle: 'Sum of paid bookings per day.',
          height: chartHeight,
          showLoadingOverlay: showLoadingOverlay,
          loadingOverlayLabel: 'Loading analytics…',
          child: hasSales
              ? _AdminSalesLineChart(
                  labels: salesLabels,
                  values: salesValues,
                )
              : const _AdminChartEmpty(message: 'No sales data yet.'),
        );

        final popularityCard = _AdminChartCard(
          title: 'Venue popularity',
          subtitle: 'Share of paid bookings by venue.',
          height: chartHeight,
          showLoadingOverlay: showLoadingOverlay,
          loadingOverlayLabel: 'Loading analytics…',
          child: hasPopularity
              ? _AdminPopularityDonutChart(
                  labels: popularityLabels,
                  values: popularityValues,
                )
              : const _AdminChartEmpty(message: 'No booking data yet.'),
        );

        if (!wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              salesCard,
              const SizedBox(height: 16),
              popularityCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: salesCard),
            const SizedBox(width: 16),
            Expanded(child: popularityCard),
          ],
        );
      },
    );
  }
}

class _AdminChartCard extends StatelessWidget {
  const _AdminChartCard({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.child,
    this.showLoadingOverlay = false,
    this.loadingOverlayLabel,
  });

  final String title;
  final String subtitle;
  final double height;
  final Widget child;
  final bool showLoadingOverlay;
  final String? loadingOverlayLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          AdminGlassCard(
            padding: const EdgeInsets.all(18),
            tint: AdminPalette.surfaceCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AdminPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminPalette.textPrimary.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(child: child),
              ],
            ),
          ),
          if (showLoadingOverlay)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AdminSectionLoadingOverlay(
                  label: loadingOverlayLabel ?? 'Loading…',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminChartEmpty extends StatelessWidget {
  const _AdminChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AdminPalette.surfaceHover,
        border: Border.all(color: AdminPalette.border.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AdminPalette.textPrimary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSalesLineChart extends StatelessWidget {
  const _AdminSalesLineChart({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  static String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > months.length) return '';
    return months[month - 1];
  }

  String _formatAxisDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return '${_monthShort(parsed.month)} ${parsed.day}';
    }
    final parts = trimmed.split('-');
    if (parts.length >= 3) {
      return '${parts[2]}/${parts[1]}';
    }
    return trimmed;
  }

  String _formatTooltipDate(String raw) {
    final trimmed = raw.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    return '${_monthShort(parsed.month)} ${parsed.day}, ${parsed.year}';
  }

  (_NiceScale, double) _computeScale() {
    final maxValue = values.fold<double>(0, (max, value) => value > max ? value : max);
    if (maxValue <= 0) {
      return (const _NiceScale(maxY: 1, step: 1), 1);
    }
    final nice = _NiceScale.from(maxValue);
    final safeMax = nice.maxY > 0 ? nice.maxY : maxValue;
    return (nice, safeMax);
  }

  @override
  Widget build(BuildContext context) {
    final points = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      points.add(FlSpot(i.toDouble(), values[i]));
    }

    final (scale, maxY) = _computeScale();

    final maxX = values.isEmpty ? 0.0 : (values.length - 1).toDouble();
    final intervalX = values.length <= 1
        ? 1.0
        : ((values.length - 1) / 5).clamp(1, values.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          horizontalInterval: scale.step,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF0F172A).withValues(alpha: 0.55),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: scale.step,
              reservedSize: 74,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    adminFormatIdrCompact(value.round()),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminPalette.textPrimary.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: intervalX,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatAxisDate(labels[index]),
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminPalette.textPrimary.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AdminPalette.backgroundBase.withValues(alpha: 0.9),
            tooltipBorder: BorderSide(color: AdminPalette.border.withValues(alpha: 0.22)),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final idx = spot.x.round();
                final dateLabel = idx >= 0 && idx < labels.length ? _formatTooltipDate(labels[idx]) : '';
                return LineTooltipItem(
                  '$dateLabel\n',
                  GoogleFonts.plusJakartaSans(
                    color: AdminPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: adminFormatIdr(spot.y.round()),
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AdminPalette.salesLine,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AdminPalette.salesLine,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AdminPalette.salesLine.withValues(alpha: 0.22),
                  AdminPalette.salesLine.withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _AdminPopularityDonutChart extends StatelessWidget {
  const _AdminPopularityDonutChart({required this.labels, required this.values});

  final List<String> labels;
  final List<int> values;

  static const int _previewRows = 3;

  List<_PopularitySlice> _sortedNonZeroSlices() {
    final slices = <_PopularitySlice>[];
    for (var i = 0; i < labels.length; i++) {
      final count = i < values.length ? values[i] : 0;
      slices.add(
        _PopularitySlice(
          label: labels[i],
          value: count,
          color: AdminPalette.popularityPalette[i % AdminPalette.popularityPalette.length],
        ),
      );
    }
    final nonZero = slices.where((slice) => slice.value > 0).toList();
    nonZero.sort((a, b) => b.value.compareTo(a.value));
    return nonZero;
  }

  void _showLegendSheet(
    BuildContext context, {
    required List<_PopularitySlice> slices,
    required int total,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AdminPalette.backgroundBase.withValues(alpha: 0.72),
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: AdminModalSheet(
                  title: 'Venue popularity',
                  scrollController: scrollController,
                  onClose: () => Navigator.of(context).pop(),
                  bodyPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  body: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: slices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final slice = slices[index];
                      final percentage =
                          total > 0 ? (slice.value / total) * 100 : 0.0;
                      final label = slice.label.trim().isEmpty
                          ? 'Unknown venue'
                          : slice.label.trim();
                      final suffix =
                          slice.value == 1 ? 'booking' : 'bookings';
                      final percentageLabel = total > 0
                          ? (percentage >= 10
                              ? '${percentage.toStringAsFixed(0)}%'
                              : '${percentage.toStringAsFixed(1)}%')
                          : '';
                      return AdminGlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        tint: AdminPalette.surfaceHover,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: slice.color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AdminPalette.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${slice.value} $suffix${percentageLabel.isEmpty ? '' : ' ($percentageLabel)'}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AdminPalette.textPrimary
                                          .withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedNonZeroSlices();
    final total = sorted.fold<int>(0, (sum, slice) => sum + slice.value);
    final preview = sorted.take(_previewRows).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 220.0;
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final isNarrow = maxWidth < 420;
        final chartScale = isNarrow ? 0.5 : 0.45;
        final chartSize = (math.min(maxHeight, maxWidth * chartScale)).clamp(130.0, maxHeight);

        final outerRadius = chartSize / 2;
        final innerRadius = outerRadius * 0.58;
        final thickness = outerRadius - innerRadius;

        final chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: innerRadius,
              startDegreeOffset: -90,
              sections: sorted
                  .map(
                    (slice) => PieChartSectionData(
                      value: slice.value.toDouble(),
                      color: slice.color,
                      radius: thickness,
                      title: '',
                      showTitle: false,
                      borderSide: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
            duration: const Duration(milliseconds: 260),
          ),
        );

        final legend = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview.isNotEmpty)
              ...preview.map(
                (slice) {
                  final label =
                      slice.label.trim().isNotEmpty ? slice.label.trim() : 'Unknown venue';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AdminLegendRow(color: slice.color, label: label),
                  );
                },
              ),
            if (sorted.length > preview.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showLegendSheet(
                    context,
                    slices: sorted,
                    total: total,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminPalette.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.unfold_more_rounded, size: 18),
                  label: Text(
                    'Show more (${sorted.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 14),
            Expanded(child: Center(child: legend)),
          ],
        );
      },
    );
  }
}

class _AdminLegendRow extends StatelessWidget {
  const _AdminLegendRow({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tint: AdminPalette.surfaceHover,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AdminPalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularitySlice {
  const _PopularitySlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _NiceScale {
  const _NiceScale({required this.maxY, required this.step});

  final double maxY;
  final double step;

  factory _NiceScale.from(double maxValue) {
    if (!(maxValue > 0)) return const _NiceScale(maxY: 1, step: 1);

    final exponent = (math.log(maxValue) / math.ln10).floor();
    final magnitude = math.pow(10.0, exponent).toDouble();
    final normalized = maxValue / magnitude;
    double niceNormalized;

    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    final suggestedMax = niceNormalized * magnitude;
    final step = suggestedMax / 5;
    return _NiceScale(maxY: suggestedMax, step: step > 0 ? step : 1);
  }
}

class AdminVenuesSection extends StatelessWidget {
  const AdminVenuesSection({
    super.key,
    required this.searchController,
    required this.venues,
    required this.meta,
    required this.loading,
    required this.error,
    required this.analyticsMeta,
    required this.analyticsLoading,
    required this.sortKey,
    required this.sortAscending,
    required this.onSortKeyChanged,
    required this.onToggleSortDirection,
    required this.onRefresh,
    required this.onSearch,
    required this.onClearSearch,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onEdit,
    required this.onDelete,
  });

  final TextEditingController searchController;
  final List<Map<String, dynamic>> venues;
  final Map<String, dynamic>? meta;
  final bool loading;
  final String? error;
  final Map<String, dynamic>? analyticsMeta;
  final bool analyticsLoading;
  final AdminVenueSortKey sortKey;
  final bool sortAscending;
  final ValueChanged<AdminVenueSortKey> onSortKeyChanged;
  final VoidCallback onToggleSortDirection;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    final showOverlay = loading && error == null;
    final overlayLabel = searchController.text.trim().isNotEmpty
        ? 'Searching venues…'
        : 'Loading venues…';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          AdminAnalyticsPanel(
            bookingsMeta: analyticsMeta,
            loading: analyticsLoading,
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminSearchCard(
                    controller: searchController,
                    hint: 'Search venues',
                    loading: loading,
                    onSubmitted: (_) => onSearch(),
                    onClear: onClearSearch,
                  ),
                  const SizedBox(height: 12),
                  AdminSortBar<AdminVenueSortKey>(
                    options: AdminVenueSortKey.values,
                    value: sortKey,
                    ascending: sortAscending,
                    enabled: !loading,
                    labelBuilder: (value) => value.label,
                    onChanged: onSortKeyChanged,
                    onToggleDirection: onToggleSortDirection,
                  ),
                  const SizedBox(height: 14),
                  if (error != null)
                    AdminErrorBanner(message: error!)
                  else if (venues.isEmpty && !loading)
                    const AdminEmptyCard(
                      title: 'No venues yet',
                      subtitle:
                          'Create your first venue to start accepting bookings.',
                    )
                  else if (venues.isEmpty)
                    const SizedBox(height: 240)
                  else
                    ...venues.map(
                      (venue) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminVenueCard(
                          venue: venue,
                          onEdit: () => onEdit(venue),
                          onDelete: () => onDelete(venue),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  AdminPaginationRow(
                    meta: meta,
                    loading: loading,
                    onPrevious: onPreviousPage,
                    onNext: onNextPage,
                  ),
                ],
              ),
              if (showOverlay)
                Positioned.fill(
                  child: AdminSectionLoadingOverlay(label: overlayLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminBookingsSection extends StatelessWidget {
  const AdminBookingsSection({
    super.key,
    required this.searchController,
    required this.bookings,
    required this.meta,
    required this.loading,
    required this.error,
    required this.sortKey,
    required this.sortAscending,
    required this.onSortKeyChanged,
    required this.onToggleSortDirection,
    required this.onRefresh,
    required this.onSearch,
    required this.onClearSearch,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onEdit,
    required this.onDelete,
  });

  final TextEditingController searchController;
  final List<Map<String, dynamic>> bookings;
  final Map<String, dynamic>? meta;
  final bool loading;
  final String? error;
  final AdminBookingSortKey sortKey;
  final bool sortAscending;
  final ValueChanged<AdminBookingSortKey> onSortKeyChanged;
  final VoidCallback onToggleSortDirection;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    final showOverlay = loading && error == null;
    final overlayLabel = searchController.text.trim().isNotEmpty
        ? 'Searching bookings…'
        : 'Loading bookings…';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminSearchCard(
                    controller: searchController,
                    hint: 'Search bookings',
                    loading: loading,
                    onSubmitted: (_) => onSearch(),
                    onClear: onClearSearch,
                  ),
                  const SizedBox(height: 12),
                  AdminSortBar<AdminBookingSortKey>(
                    options: AdminBookingSortKey.values,
                    value: sortKey,
                    ascending: sortAscending,
                    enabled: !loading,
                    labelBuilder: (value) => value.label,
                    onChanged: onSortKeyChanged,
                    onToggleDirection: onToggleSortDirection,
                  ),
                  const SizedBox(height: 14),
                  if (error != null)
                    AdminErrorBanner(message: error!)
                  else if (bookings.isEmpty && !loading)
                    const AdminEmptyCard(
                      title: 'No bookings yet',
                      subtitle:
                          'Once users start reserving venues, they will appear here.',
                    )
                  else if (bookings.isEmpty)
                    const SizedBox(height: 240)
                  else
                    ...bookings.map(
                      (booking) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminBookingCard(
                          booking: booking,
                          onEdit: () => onEdit(booking),
                          onDelete: () => onDelete(booking),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  AdminPaginationRow(
                    meta: meta,
                    loading: loading,
                    onPrevious: onPreviousPage,
                    onNext: onNextPage,
                  ),
                ],
              ),
              if (showOverlay)
                Positioned.fill(
                  child: AdminSectionLoadingOverlay(label: overlayLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminDialogs {
  const AdminDialogs._();

  static Future<void> confirmDeleteVenue({
    required BuildContext context,
    required Map<String, dynamic> venue,
    required Future<void> Function() onDeleted,
  }) async {
    final title = (venue['title'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete venue?'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final id = adminSafeInt(venue['id']);
      await Api().adminDeleteVenue(venueId: id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue deleted')),
      );
      await onDeleted();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  static Future<void> confirmDeleteBooking({
    required BuildContext context,
    required Map<String, dynamic> booking,
    required Future<void> Function() onDeleted,
  }) async {
    final label =
        (booking['guest_label'] ?? booking['username'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('Delete "$label"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final id = adminSafeInt(booking['id']);
      await Api().adminDeleteBooking(bookingId: id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking deleted')),
      );
      await onDeleted();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
