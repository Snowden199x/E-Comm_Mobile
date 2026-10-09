import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendo_rider/features/dashboard/screens/deliveries_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/earnings_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/home_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/map_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the Home, Deliveries, Earnings and Profile screens
//  • Prune  → active tab
// ─────────────────────────────────────────────────────────────────────────────
class _DashColors {
  static const background = Color(0xFFFAF7F5);
  static const prune = Color(0xFF412143);
  static const inactive = Color(0xFF8C8290);
  static const shadow = Color(0x1A412143);
}

// Tab positions, so the code below reads clearly
class _Tab {
  static const home = 0;
  static const parcels = 1;
  static const map = 2;
  static const earnings = 3;
  static const profile = 4;
  // ignore_for_file: unused_field
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = _Tab.home;

  // Map tab uses a fixed placeholder destination — Bubukal, Santa Cruz, Laguna
  static const _mapDestination = LatLng(14.2789, 121.4244);
  static const _mapLabel = 'Brgy. Bubukal, Santa Cruz, Laguna';

  late final List<Widget> _pages = [
    HomeScreen(onViewEarnings: () => _onTabSelected(_Tab.parcels)),
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
    // Back button: from any other tab go to Home first,
    // and only leave the app when already on Home.
    return PopScope(
      canPop: _selectedTab == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedTab = _Tab.home);
      },
      child: Scaffold(
        backgroundColor: _DashColors.background,
        body: IndexedStack(index: _selectedTab, children: _pages),
        bottomNavigationBar: _BottomNav(
          selectedIndex: _selectedTab,
          items: _navItems,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation with a "jelly" indicator
//
// One dark purple pill slides to the tab you tap. While it travels it
// stretches toward where you tapped (the front edge runs ahead, the back edge
// follows late), then it wobbles a little and settles, like jelly.
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatefulWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav>
    with SingleTickerProviderStateMixin {
  // ── Easy to tweak ──────────────────────────────────────────────────────
  static const _pillWidth = 56.0;
  static const _pillHeight = 32.0;
  static const _duration = Duration(milliseconds: 650); // longer = slower
  static const _squash = 0.14; // how much the pill flattens while travelling
  // ───────────────────────────────────────────────────────────────────────

  late final AnimationController _controller;
  late int _fromIndex;

  // Front edge: runs ahead quickly
  static final _leadCurve = Interval(0.0, 0.55, curve: Curves.easeOutCubic);

  // Back edge: starts a little later, then wobbles into place (the jelly part)
  static final _trailCurve = Interval(0.1, 1.0, curve: ElasticOutCurve(0.8));

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1.0, // start already settled on the first tab
    );
  }

  @override
  void didUpdateWidget(covariant _BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _fromIndex = oldWidget.selectedIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Where the pill is right now
  _PillShape _pillShape(double cell) {
    final t = _controller.value;
    final from = _fromIndex;
    final to = widget.selectedIndex;

    final fromCenter = cell * (from + 0.5);
    final toCenter = cell * (to + 0.5);
    final half = _pillWidth / 2;

    final movingRight = to >= from;
    final leadT = _leadCurve.transform(t);
    final trailT = _trailCurve.transform(t);

    // The edge facing the destination leads, the other edge trails behind
    final leftT = movingRight ? trailT : leadT;
    final rightT = movingRight ? leadT : trailT;

    final left =
        (fromCenter - half) + ((toCenter - half) - (fromCenter - half)) * leftT;
    final right =
        (fromCenter + half) +
        ((toCenter + half) - (fromCenter + half)) * rightT;

    // Flatten a little in the middle of the trip, then bounce back
    final height = _pillHeight * (1 - _squash * math.sin(math.pi * t));
    final top = (_pillHeight - height) / 2;

    return _PillShape(left: left, right: right, top: top, height: height);
  }

  // Icon turns white where the pill covers it, grey where it does not
  Color _iconColor(int index, double cell, _PillShape pill) {
    final center = cell * (index + 0.5);
    const iconHalf = 12.0;
    final overlap =
        (math.min(pill.right, center + iconHalf) -
            math.max(pill.left, center - iconHalf)) /
        (iconHalf * 2);
    final amount = overlap.clamp(0.0, 1.0).toDouble();
    return Color.lerp(_DashColors.inactive, Colors.white, amount)!;
  }

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / widget.items.length;

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final pill = _pillShape(cell);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The jelly pill (behind the icons)
                      Positioned(
                        left: pill.left,
                        top: pill.top,
                        width: math.max(pill.right - pill.left, 0),
                        height: pill.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _DashColors.prune,
                            borderRadius: BorderRadius.circular(
                              pill.height / 2,
                            ),
                          ),
                        ),
                      ),
                      // Icons and labels (on top)
                      Row(
                        children: List.generate(widget.items.length, (i) {
                          return Expanded(
                            child: _NavButton(
                              item: widget.items[i],
                              isActive: i == widget.selectedIndex,
                              iconColor: _iconColor(i, cell, pill),
                              iconAreaHeight: _pillHeight,
                              onTap: () => widget.onTap(i),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PillShape {
  final double left, right, top, height;

  const _PillShape({
    required this.left,
    required this.right,
    required this.top,
    required this.height,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final Color iconColor;
  final double iconAreaHeight;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.iconColor,
    required this.iconAreaHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            SizedBox(
              height: iconAreaHeight,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    key: ValueKey(isActive),
                    size: 24,
                    color: iconColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _DashColors.prune : _DashColors.inactive,
              ),
              child: Text(item.label, maxLines: 1),
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
