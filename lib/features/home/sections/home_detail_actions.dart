part of 'package:tk2ragaspace/features/home/home_screen.dart';

class _AddonSelectionPanel extends StatelessWidget {
  const _AddonSelectionPanel({
    required this.addons,
    required this.selectedIndexes,
    required this.onToggle,
  });

  final List<_VenueAddon> addons;
  final Set<int> selectedIndexes;
  final void Function(int index, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (addons.isEmpty) {
      return const SizedBox.shrink();
    }
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 24,
      overlayColor: const Color(0x22102745),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tambah add-ons ke pesananmu',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...addons.asMap().entries.map((entry) {
            final index = entry.key;
            final addon = entry.value;
            final isSelected = selectedIndexes.contains(index);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == addons.length - 1 ? 0 : 12,
              ),
              child: _AddonCheckboxTile(
                addon: addon,
                selected: isSelected,
                onChanged: (value) => onToggle(index, value),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AddonCheckboxTile extends StatelessWidget {
  const _AddonCheckboxTile({
    required this.addon,
    required this.selected,
    required this.onChanged,
  });

  final _VenueAddon addon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF1FA2FF)
                : Colors.white.withValues(alpha: 0.18),
          ),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: const Color(0xFF1FA2FF),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 10),
            Expanded(
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(addon.price),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8AE8FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (addon.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        addon.description,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBottomBar extends StatelessWidget {
  const _DetailBottomBar({required this.onTapBook, required this.category});

  final VoidCallback onTapBook;
  final String category;

  IconData _categoryIcon() {
    final lower = category.toLowerCase();
    final match = _categories.firstWhere(
      (chip) => chip.label.toLowerCase() == lower,
      orElse: () => _categories.first,
    );
    return match.icon;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF45B1FF), Color(0xFF4BE2C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF45B1FF).withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: onTapBook,
                icon: Icon(_categoryIcon(), color: Colors.white),
                label: Text(
                  'Book now',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
