import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/core/push/rider_push_service.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/notifications/rider_notification_center.dart';
import 'package:vendo_rider/core/offline/offline_sync_service.dart';
import 'package:vendo_rider/features/dashboard/screens/deliveries_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/earnings_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/home_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/notifications_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/profile_screen.dart';
import 'package:vendo_rider/features/dashboard/widgets/rider_notice_banner.dart';
import 'package:vendo_rider/features/scanner/screens/parcel_scanner_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the Home, Deliveries, Earnings and Profile screens
//  • Prune  → active tab
// ─────────────────────────────────────────────────────────────────────────────
class _DashColors {
  static const background = Color(0xFFFAF7F5);
  static const prune = Color(0xFF412143);
  static const inactive = Color(0xFF8C8290);
  static const shadow = Color(0x1A412143);
  static const border = Color(0xFFECE6EA);

  // See-through bar: white at about 70% so the page shows through
  static const glass = Color(0xB3FFFFFF);
  static const glassBorder = Color(0x33412143);

  // Centre scan button: dark purple disc with a small soft glow
  static const scan = Color(0xFF412143); // same as prune
  static const scanGlow = Color(0x667B3F8C); // lighter purple, see-through
}

// Tab positions, so the code below reads clearly
class _Tab {
  static const home = 0;
  static const parcels = 1;
  // Index 2 is the centre scan button, not a page tab; the Notifications page
  // still lives at this index and is opened from the Home bell or the banner.
  static const notifications = 2;
  static const earnings = 3;
  static const profile = 4;
  // ignore_for_file: unused_field
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _selectedTab = _Tab.home;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _parcelsKey = GlobalKey<DeliveriesScreenState>();
  final _notificationsKey = GlobalKey<NotificationsScreenState>();
  final _earningsRefresh = ValueNotifier<int>(0);
  final _notifications = RiderNotificationCenter.instance;

  late final List<Widget> _pages = [
    HomeScreen(
      key: _homeKey,
      onOpenParcels: () => _onTabSelected(_Tab.parcels),
      onOpenEarnings: () => _onTabSelected(_Tab.earnings),
      onOpenNotifications: () => _onTabSelected(_Tab.notifications),
    ),
    DeliveriesScreen(key: _parcelsKey),
    NotificationsScreen(key: _notificationsKey),
    EarningsScreen(refreshSignal: _earningsRefresh),
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
    // Placeholder for the middle slot; the floating scan button is drawn on
    // top of it, so this entry is never rendered as a tab.
    _NavItem(
      icon: Icons.qr_code_scanner_rounded,
      activeIcon: Icons.qr_code_scanner_rounded,
      label: 'Scan',
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifications.start();
    // Push tokens are registered after sign-in; polling remains the fallback.
    RiderPushService.instance.start();
    // Watch for the connection returning so queued scans upload immediately.
    OfflineSyncService.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifications.stop();
    OfflineSyncService.instance.stop();
    RiderPushService.instance.reset();
    _earningsRefresh.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifications.poll();
      // Android stops reporting connectivity changes in the background, so
      // retry the offline outbox whenever the Rider returns to the app.
      OfflineSyncService.instance.syncNow();
    }
  }

  void _openBannerNotice() {
    // A parcel assignment or a closed delivery window is work the rider can
    // act on in Parcels, so open that tab; everything else opens the list.
    final assignment = const {
      'rider_task_assigned',
      'delivery_window_closed',
    }.contains(_notifications.banner?.type);
    _notifications.dismissBanner();
    _onTabSelected(assignment ? _Tab.parcels : _Tab.notifications);
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) {
      if (index == _Tab.home) _homeKey.currentState?.refreshAssignments();
      if (index == _Tab.parcels) _parcelsKey.currentState?.refreshAssignments();
      if (index == _Tab.notifications)
        _notificationsKey.currentState?.refreshNotifications();
      if (index == _Tab.earnings) _earningsRefresh.value++;
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = index);
    if (index == _Tab.home) _homeKey.currentState?.refreshAssignments();
    if (index == _Tab.parcels) _parcelsKey.currentState?.refreshAssignments();
    if (index == _Tab.notifications)
      _notificationsKey.currentState?.refreshNotifications();
    if (index == _Tab.earnings) _earningsRefresh.value++;
  }

  /// Scans a parcel label and opens that parcel's delivery details.
  Future<void> _scanToParcel() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ParcelScannerScreen()),
    );
    if (!mounted || scanned == null) return;

    final code = scanned.trim().toLowerCase();
    if (code.isEmpty) return;

    // Fresh list first; fall back to the work saved on this device offline.
    List<Map<String, dynamic>> work;
    try {
      work = await RiderApi.instance.assignments();
    } catch (_) {
      final cached = await RiderApi.instance.cachedWork();
      if (!mounted) return;
      if (cached == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot reach Vendo. Try again when you have signal.',
            ),
          ),
        );
        return;
      }
      work = (cached.payload['assignments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (!mounted) return;

    Map<String, dynamic>? match;
    for (final order in work) {
      final tracking = '${order['tracking_number'] ?? ''}'.trim().toLowerCase();
      final orderId = '${order['order_id'] ?? ''}'.trim();
      if (tracking.isNotEmpty && tracking == code) {
        match = order;
        break;
      }
      if (orderId.isNotEmpty && orderId == code) {
        match = order;
        break;
      }
      // Labels sometimes carry the tracking number inside a longer payload.
      if (tracking.length >= 6 && code.contains(tracking)) {
        match = order;
        break;
      }
    }

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$scanned is not one of your parcels.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeliveryDetailScreen(order: match!)),
    );
    if (mounted) await _parcelsKey.currentState?.refreshAssignments();
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
      child: ListenableBuilder(
        listenable: _notifications,
        builder: (context, _) => Scaffold(
          // The page continues behind the see-through bar
          extendBody: true,
          backgroundColor: _DashColors.background,
          body: Stack(
            children: [
              IndexedStack(index: _selectedTab, children: _pages),
              // New notifications slide in over the top of every tab.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: RiderNoticeBanner(
                    notice: _notifications.banner,
                    onTap: _openBannerNotice,
                    onDismiss: _notifications.dismissBanner,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            selectedIndex: _selectedTab,
            items: _navItems,
            onTap: _onTabSelected,
            onScan: _scanToParcel,
          ),
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
  final VoidCallback onScan;

  const _BottomNav({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
    required this.onScan,
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
  static const _barTop = 32.0; // space above the bar (room for the scan button)
  static const _scanTop = 2.0; // scan button height: bigger = lower
  static const _notchGap = 8.0; // clear space between the button and the bar
  // The curve in the bar is a circle around the scan button.
  static const _notchRadius = _ScanButton._disc / 2 + _notchGap;
  static const _notchCenterY = _scanTop + _ScanButton._tapArea / 2 - _barTop;
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
    // Floating bar: rounded all around, lifted off the bottom edge, with a
    // soft shadow. The jelly pill and icons inside are unchanged.
    // The bar has a round cut-out in the middle so the scan button floats.
    const shape = _NotchedBarShape(
      notchRadius: _notchRadius,
      notchCenterY: _notchCenterY,
      borderColor: _DashColors.glassBorder,
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      // The bar keeps the padding room above it that the scan button needs.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, _barTop, 16, 6),
            child: Container(
              // Soft shadow around the bar
              decoration: const ShapeDecoration(
                shape: shape,
                shadows: [
                  BoxShadow(
                    color: Color(0x1F412143),
                    blurRadius: 24,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                // Frosted glass: the content behind the bar is blurred, not hidden
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const ShapeDecoration(
                      color: _DashColors.glass,
                      shape: shape,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cell = constraints.maxWidth / widget.items.length;

                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final pill = _pillShape(cell);
                            // Index 2 is the scan button: no pill while it is the tab.
                            final onScanSlot =
                                widget.selectedIndex == _Tab.notifications ||
                                _fromIndex == _Tab.notifications;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // The jelly pill (behind the icons)
                                if (!onScanSlot)
                                  Positioned(
                                    left: pill.left,
                                    top: pill.top + _vPad,
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
                                  children: List.generate(widget.items.length, (
                                    i,
                                  ) {
                                    // The middle slot is empty: the scan button floats
                                    // over it.
                                    if (i == _Tab.notifications) {
                                      return const Expanded(
                                        child: SizedBox.shrink(),
                                      );
                                    }
                                    return Expanded(
                                      child: _NavButton(
                                        item: widget.items[i],
                                        isActive: i == widget.selectedIndex,
                                        iconColor: _iconColor(i, cell, pill),
                                        iconAreaHeight: _pillHeight,
                                        verticalPadding: _vPad,
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
              ),
            ),
          ),
          // Centre scan button: floats in the curve of the bar. Change
          // _scanTop above to move it (the curve follows it automatically).
          Positioned(
            top: _scanTop,
            left: 0,
            right: 0,
            child: Center(child: _ScanButton(onTap: widget.onScan)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Centre scan button
// ─────────────────────────────────────────────────────────────────────────────
class _ScanButton extends StatelessWidget {
  static const _tapArea = 66.0; // invisible, just keeps the tap area big
  static const _disc = 52.0;

  final VoidCallback onTap;

  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan parcel',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _tapArea,
          height: _tapArea,
          child: Center(
            child: Container(
              width: _disc,
              height: _disc,
              decoration: const BoxDecoration(
                color: _DashColors.scan,
                shape: BoxShape.circle,
                boxShadow: [
                  // Small soft glow around the disc. Raise blurRadius or
                  // spreadRadius for a bigger glow, lower them for less.
                  BoxShadow(
                    color: _DashColors.scanGlow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  // Soft drop shadow underneath
                  BoxShadow(
                    color: Color(0x40412143),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar shape: a pill with a round bite taken out of the top middle, so the scan
// button looks separated from the bar and floating.
// ─────────────────────────────────────────────────────────────────────────────
class _NotchedBarShape extends ShapeBorder {
  final double notchRadius;
  final double
  notchCenterY; // distance from the bar's top edge to the circle centre
  final Color borderColor;

  const _NotchedBarShape({
    required this.notchRadius,
    required this.notchCenterY,
    required this.borderColor,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = rect.height / 2;
    final cx = rect.center.dx;
    final cy = rect.top + notchCenterY;
    final radius = notchRadius;
    const soften =
        8.0; // rounds the sharp corners where the curve meets the top

    // Where the circle crosses the top edge
    final w = math.sqrt(radius * radius - notchCenterY * notchCenterY);
    final phi0 = math.atan2(-notchCenterY, -w) + 2 * math.pi;
    final phiL = phi0 - 0.25; // start of the circle arc (left)
    final phiR = math.pi - phiL; // end of the circle arc (right)

    Offset onCircle(double a) =>
        Offset(cx + radius * math.cos(a), cy + radius * math.sin(a));
    Offset heading(double a) => Offset(math.sin(a), -math.cos(a));

    final endL = onCircle(phiL);
    final endR = onCircle(phiR);
    final dirL = heading(phiL);
    final dirR = heading(phiR);

    final path = Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(cx - w - soften, rect.top)
      ..cubicTo(
        cx - w - soften + 5,
        rect.top,
        endL.dx - dirL.dx * 4,
        endL.dy - dirL.dy * 4,
        endL.dx,
        endL.dy,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        phiL,
        math.pi - 2 * phiL,
        false,
      )
      ..cubicTo(
        endR.dx + dirR.dx * 4,
        endR.dy + dirR.dy * 4,
        cx + w + soften - 5,
        rect.top,
        cx + w + soften,
        rect.top,
      )
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r))
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.top + r), radius: Radius.circular(r))
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: Radius.circular(r))
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = borderColor,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
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

class _NavItem {
  final IconData icon, activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
