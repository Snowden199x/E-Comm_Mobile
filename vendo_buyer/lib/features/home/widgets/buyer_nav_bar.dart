import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Floating bottom navigation for the Buyer app — same look and motion as the
// Rider dashboard bar: a rounded, frosted bar lifted off the bottom edge, with
// one dark pill that bounces and stretches ("jelly") as it travels to the tab
// you tapped.
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom space a page must leave so its last row can scroll clear of the
/// floating bar: the bar itself (52), its 6 px margins and the 10 px lift, plus
/// a little breathing room. Add `MediaQuery.padding.bottom` to it.
const double kBuyerNavBarClearance = 78;

class _NavColors {
  static const prune = Color(0xFF2D1B3D);
  static const inactive = Color(0xFF8C8290);

  // Mostly transparent bar so the page behind it stays visible through the blur.
  static const glass = Color(0x99FFFFFF);
  static const glassBorder = Color(0x332D1B3D);
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

/// Bottom navigation bar. The screen owns the selected index and receives the
/// taps through [onTap].
class BuyerNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BuyerNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<BuyerNavBar> createState() => _BuyerNavBarState();
}

class _BuyerNavBarState extends State<BuyerNavBar>
    with SingleTickerProviderStateMixin {
  // ── Easy to tweak ──────────────────────────────────────────────────────
  static const _pillWidth = 56.0;
  static const _pillHeight = 32.0;
  static const _duration = Duration(milliseconds: 650); // longer = slower
  static const _squash = 0.14; // how much the pill flattens while travelling
  static const _hop = 4.0; // how high the pill jumps on its way there
  static const _vPad = 10.0; // space above and below the icons (tap area)
  // ───────────────────────────────────────────────────────────────────────

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Saves',
    ),
    _NavItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Notification',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  late final AnimationController _controller;
  late int _fromIndex;

  // Front edge: runs ahead quickly.
  static final _leadCurve = Interval(0.0, 0.55, curve: Curves.easeOutCubic);

  // Back edge: starts a little later, then wobbles into place (the jelly part).
  static final _trailCurve = Interval(0.12, 1.0, curve: ElasticOutCurve(0.8));

  // The pill hops up and settles back down while it travels.
  static final _hopCurve = Interval(0.1, 0.9, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1.0, // start already settled on the first tab
    );
  }

  @override
  void didUpdateWidget(covariant BuyerNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Where the pill is right now.
  _PillShape _pillShape(double cell) {
    final t = _controller.value;
    final from = _fromIndex;
    final to = widget.currentIndex;

    final fromCenter = cell * (from + 0.5);
    final toCenter = cell * (to + 0.5);
    final half = _pillWidth / 2;

    final movingRight = to >= from;
    final leadT = _leadCurve.transform(t);
    final trailT = _trailCurve.transform(t);

    // The edge facing the destination leads, the other edge trails behind.
    final leftT = movingRight ? trailT : leadT;
    final rightT = movingRight ? leadT : trailT;

    final left =
        (fromCenter - half) + ((toCenter - half) - (fromCenter - half)) * leftT;
    final right =
        (fromCenter + half) +
        ((toCenter + half) - (fromCenter + half)) * rightT;

    // Flatten a little in the middle of the trip, then bounce back.
    final height = _pillHeight * (1 - _squash * math.sin(math.pi * t));
    final top = (_pillHeight - height) / 2;

    // A short hop over the trip; it lands exactly where the pill settles.
    final lift = _hop * math.sin(math.pi * _hopCurve.transform(t));

    return _PillShape(
      left: left,
      right: right,
      top: top,
      height: height,
      lift: lift,
    );
  }

  // Icon turns white where the pill covers it, grey where it does not.
  Color _iconColor(int index, double cell, _PillShape pill) {
    final center = cell * (index + 0.5);
    const iconHalf = 12.0;
    final overlap =
        (math.min(pill.right, center + iconHalf) -
            math.max(pill.left, center - iconHalf)) /
        (iconHalf * 2);
    final amount = overlap.clamp(0.0, 1.0).toDouble();
    return Color.lerp(_NavColors.inactive, Colors.white, amount)!;
  }

  void _onTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    // Floating bar: rounded on every corner, lifted off the bottom edge, with a
    // soft shadow and a frosted background.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F2D1B3D),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            // Frosted glass: whatever sits behind the bar is blurred.
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _NavColors.glass,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: _NavColors.glassBorder),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cell = constraints.maxWidth / _items.length;

                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final pill = _pillShape(cell);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // The bouncing pill (behind the icons).
                            Positioned(
                              left: pill.left,
                              top: pill.top + _vPad - pill.lift,
                              width: math.max(pill.right - pill.left, 0),
                              height: pill.height,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _NavColors.prune,
                                  borderRadius: BorderRadius.circular(
                                    pill.height / 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x332D1B3D),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Icons and labels (on top).
                            Row(
                              children: List.generate(_items.length, (i) {
                                return Expanded(
                                  child: _NavButton(
                                    item: _items[i],
                                    isActive: i == widget.currentIndex,
                                    iconColor: _iconColor(i, cell, pill),
                                    iconAreaHeight: _pillHeight,
                                    verticalPadding: _vPad,
                                    onTap: () => _onTap(i),
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
          ),
        ),
      ),
    );
  }
}

class _PillShape {
  final double left, right, top, height, lift;

  const _PillShape({
    required this.left,
    required this.right,
    required this.top,
    required this.height,
    required this.lift,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
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
            // No visible label: the icon alone keeps the bar short. The label
            // stays on the button's Semantics node for screen readers.
            SizedBox(height: verticalPadding),
          ],
        ),
      ),
    );
  }
}
