import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';

class DriverNavItem {
  const DriverNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const List<DriverNavItem> driverNavItems = [
  DriverNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  DriverNavItem(
    label: 'Trips',
    icon: Icons.route_outlined,
    activeIcon: Icons.route_rounded,
  ),
  DriverNavItem(
    label: 'Manifest',
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
  ),
  DriverNavItem(
    label: 'Earnings',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments_rounded,
  ),
  DriverNavItem(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  ),
];

class DriverBottomNav extends StatelessWidget {
  const DriverBottomNav({
    super.key,
    required this.index,
    required this.onSelected,
  });

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: VColors.border)),
        boxShadow: [
          BoxShadow(
            color: VColors.shadow,
            blurRadius: 18,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
          child: Row(
            children: [
              for (var i = 0; i < driverNavItems.length; i++)
                Expanded(
                  child: _NavTile(
                    item: driverNavItems[i],
                    selected: i == index,
                    onTap: () {
                      if (i == index) return;
                      HapticFeedback.selectionClick();
                      onSelected(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DriverNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? VColors.prune : VColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? VColors.raisinSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
