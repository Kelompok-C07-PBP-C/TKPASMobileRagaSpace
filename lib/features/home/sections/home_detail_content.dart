part of 'package:tk2ragaspace/features/home/home_screen.dart';

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.starBuilder,
    this.onEdit,
    this.onDelete,
  });

  final _VenueReview review;
  final Widget Function(int rating, {double size}) starBuilder;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      overlayColor: Colors.white.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatReadableDate(review.date),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              starBuilder(review.rating, size: 18),
              const SizedBox(width: 10),
              Text(
                review.rating.toStringAsFixed(1),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
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

class _ReviewDraft {
  const _ReviewDraft({required this.rating, required this.comment});
  final int rating;
  final String comment;
}

String _resolveMediaUrlGlobal(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final normalized = url.startsWith('/') ? url : '/$url';
  return '$_apiHostBase$normalized';
}

class _AddonInfoCard extends StatelessWidget {
  const _AddonInfoCard({required this.addon});

  final _VenueAddon addon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  addon.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatCurrency(addon.price),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8AE8FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (addon.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              addon.description,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

@visibleForTesting
Widget buildDetailChipForTests(String text) => _DetailChip(text: text);

@visibleForTesting
Widget buildReviewCardForTests({
  required String author,
  required String comment,
  required int rating,
  Widget Function(int rating, {double size})? starBuilder,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  final review = _VenueReview(
    id: 1,
    venueId: 1,
    author: author,
    comment: comment,
    rating: rating,
    date: DateTime(2025, 1, 10),
    isMine: true,
  );
  return _ReviewCard(
    review: review,
    starBuilder:
        starBuilder ?? (value, {double size = 18}) => const SizedBox.shrink(),
    onEdit: onEdit,
    onDelete: onDelete,
  );
}

@visibleForTesting
Widget buildAddonInfoCardForTests({
  required String name,
  required int price,
  String description = '',
}) {
  final addon = _VenueAddon(name: name, price: price, description: description);
  return _AddonInfoCard(addon: addon);
}

@visibleForTesting
String resolveMediaUrlGlobalForTests(String url) => _resolveMediaUrlGlobal(url);
