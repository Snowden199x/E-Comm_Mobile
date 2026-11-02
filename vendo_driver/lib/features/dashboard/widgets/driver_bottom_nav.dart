import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same navigation as the Rider app:
//  • a floating, rounded, see-through bar lifted off the bottom edge
//  • one Prune pill that slides between tabs and wobbles into place
//  • icons only, with the active one turning white where the pill covers it
// ─────────────────────────────────────────────────────────────────────────────

// See-through bar: white at about 70% so the page shows through
const Color _glass = Color(0xB3FFFFFF);
const Color _glassBorder = Color(0x33412143);

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
    return _BottomNav(
      selectedIndex: index,
      items: driverNavItems,
      onTap: onSelected,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The bar with the "jelly" indicator
//
// One dark purple pill slides to the tab you tap. While it travels it
// stretches toward where you tapped (the front edge runs ahead, the back edge
// follows late), then it wobbles a little and settles, like jelly.
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatefulWidget {
  final int selectedIndex;
  final List<DriverNavItem> items;
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
  static const _vPad = 10.0; // space above and below the icons (also tap area)
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
    return Color.lerp(VColors.muted, Colors.white, amount)!;
  }

  @override
  Widget build(BuildContext context) {
    // Floating bar: rounded all around, lifted off the bottom edge, with a
    // soft shadow. The jelly pill and icons inside are unchanged.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Container(
          // Soft shadow around the bar
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F412143),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            // Frosted glass: the content behind the bar is blurred, not hidden
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _glass,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: _glassBorder),
                ),
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
                              top: pill.top + _vPad,
                              width: math.max(pill.right - pill.left, 0),
                              height: pill.height,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: VColors.prune,
                                  borderRadius: BorderRadius.circular(
                                    pill.height / 2,
                                  ),
                                ),
                              ),
                            ),
                            // Icons (on top)
                            Row(
                              children: List.generate(
                                widget.items.length,
                                (i) => Expanded(
                                  child: _NavButton(
                                    item: widget.items[i],
                                    isActive: i == widget.selectedIndex,
                                    iconColor: _iconColor(i, cell, pill),
                                    iconAreaHeight: _pillHeight,
                                    verticalPadding: _vPad,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onTap(i);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
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
  final DriverNavItem item;
  final bool isActive;
  final Color iconColor;
  final double iconAreaHeight;
  final double verticalPadding;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.iconColor,
    required this.iconAreaHeight,
    required this.verticalPadding,
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
            SizedBox(height: verticalPadding),
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
            SizedBox(height: verticalPadding),
          ],
        ),
      ),
    );
  }
}
