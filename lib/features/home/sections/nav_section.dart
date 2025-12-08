part of 'package:tk2ragaspace/features/home/home_screen.dart';

mixin _HomeNavigationSection on _HomeScreenCore {
  Widget _buildBottomNavigation(BuildContext context) {
    final items = [
      _NavItemData(icon: Icons.home_rounded, label: 'Home'),
      _NavItemData(icon: Icons.grid_view_rounded, label: 'Catalog'),
      _NavItemData(icon: Icons.favorite_border_rounded, label: 'Wishlist'),
      _NavItemData(icon: Icons.event_available_outlined, label: 'Booked'),
    ];
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101F44),
        border: Border(top: BorderSide(color: Color(0x33132142), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            data: items[0],
            selected: _navIndex == 0,
            onTap: () => setState(() => _navIndex = 0),
          ),
          _NavItem(
            data: items[1],
            selected: _navIndex == 1,
            onTap: _openCatalog,
          ),
          _NavItem(
            data: items[2],
            selected: _navIndex == 2,
            onTap: _openWishlist,
          ),
          _NavItem(
            data: items[3],
            selected: _navIndex == 3,
            onTap: _openBookings,
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: selected ? Colors.white : Colors.white70),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
