import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendo_rider/features/dashboard/screens/deliveries_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/earnings_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/home_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/map_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors used by the dashboard shell
// ─────────────────────────────────────────────────────────────────────────────
class _DashColors {
  static const background = Color(0xFFF0EEF8);
  static const primary = Color(0xFF4A1E8C);
  static const pill = Color(0xFFEDE5FA); // soft purple behind active icon
  static const inactive = Color(0xFF9A96A8);
  static const shadow = Color(0x1A4A1E8C);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;

  // Map tab uses a fixed placeholder destination — Bubukal, Santa Cruz, Laguna
  static const _mapDestination = LatLng(14.2789, 121.4244);
  static const _mapLabel = 'Brgy. Bubukal, Santa Cruz, Laguna';

  // Built once so the pages are not recreated on every rebuild
  late final List<Widget> _pages = [
    HomeScreen(onViewEarnings: () => _onTabSelected(3)),
    const DeliveriesScreen(),
    MapScreen(destination: _mapDestination, destinationLabel: _mapLabel),
    const EarningsScreen(),
    const ProfileScreen(),
  ];

  static const _navItems = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Parcels',
    ),
    _NavItem(
      icon: Icons.location_on_outlined,
      activeIcon: Icons.location_on_rounded,
      label: 'Map',
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Earnings',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DashColors.background,
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedTab,
        items: _navItems,
        onTap: _onTabSelected,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation
// Rounded top corners, soft purple shadow, and a pill highlight on the
// active tab.
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: _DashColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _NavButton(
                  item: items[i],
                  isActive: i == selectedIndex,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _DashColors.primary : _DashColors.inactive;

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill that fades in behind the active icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? _DashColors.pill : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}