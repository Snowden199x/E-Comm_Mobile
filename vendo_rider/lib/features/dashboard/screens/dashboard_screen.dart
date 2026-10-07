import 'package:flutter/material.dart';
import 'package:vendo_rider/features/dashboard/screens/home_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/deliveries_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/map_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/earnings_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/profile_screen.dart';
import 'package:latlong2/latlong.dart';

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

  List<Widget> get _pages => [
    const HomeScreen(),
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
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Orders',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EEF8),
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedTab,
        items: _navItems,
        onTap: (i) => setState(() => _selectedTab = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation — purple underline active style matching reference
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
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == selectedIndex;
              final item = items[i];
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 24,
                        color: isActive
                            ? const Color(0xFF4A1E8C)
                            : const Color(0xFFAAAAAA),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive
                              ? const Color(0xFF4A1E8C)
                              : const Color(0xFFAAAAAA),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Purple underline for active
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: isActive ? 24 : 0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A1E8C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
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
