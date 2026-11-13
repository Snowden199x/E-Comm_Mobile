import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';
import 'package:vendo_driver/features/notifications/screens/driver_notifications_screen.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';
import 'package:vendo_driver/features/trips/screens/driver_manifest_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_scan_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_trip_status_screen.dart';

/// Slightly lighter prune for the header gradient.
const Color _pruneLight = Color(0xFF55295A);

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.onOpenTrip,
    required this.onOpenTab,
  });

  final ValueChanged<String> onOpenTrip;
  final ValueChanged<int> onOpenTab;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  // Drives the header animation (loops forever, 0.0 -> 1.0).
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  /// The bell opens its own screen and reloads the list, so a notification that
  /// arrived while the app sat in the background is not missed.
  void _openNotifications() {
    DriverStore.instance.refreshNotifications();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DriverNotificationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;
    final profile = store.profile;
    final current = store.currentTrip;
    final upcoming = store.upcomingTrips;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final firstName = profile.name.trim().isEmpty
        ? 'Driver'
        : profile.name.trim().split(RegExp(r'\s+')).first;

    // The hub and company can be blank before the web link is set, so the
    // subtitle skips the empty parts instead of leaving a stray separator.
    final subtitleParts = [
      profile.hub,
      profile.company,
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);

    // Days until the licence expires. The server refuses an expired licence, so
    // the home screen warns before the driver reaches a blocked sign-in.
    final licenceDaysLeft = DateTime(
      profile.licenseExpiry.year,
      profile.licenseExpiry.month,
      profile.licenseExpiry.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark.
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        color: VColors.brique,
        onRefresh: () => Future.wait([
          store.refreshTrips(),
          store.refreshNotifications(),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _AnimatedHeader(
              controller: _bgController,
              eyebrow: 'Vendo Xpress · Transport',
              greeting: greeting,
              name: firstName,
              subtitle: subtitleParts.isEmpty
                  ? 'Transport driver'
                  : subtitleParts.join(' · '),
              initials: profile.initials,
              dateText: fullDateLabel(now),
              vehicleText: '${profile.vehicle} · ${profile.plate}',
              unreadNotifications: store.unreadNotifications,
              onOpenNotifications: _openNotifications,
              onOpenProfile: () => widget.onOpenTab(4),
            ),
            Padding(
              padding: vPageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (licenceDaysLeft <= 30)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LicenceNotice(
                        daysLeft: licenceDaysLeft,
                        hasExpiry: profile.licenseExpiry.year > 1970,
                        onOpenProfile: () => widget.onOpenTab(4),
                      ),
                    ),
                  _SyncStrip(
                    store: store,
                    onSignIn: () => _signInAgain(context),
                  ),
                  const SizedBox(height: 16),
                  _StatsRow(store: store),
                  const SizedBox(height: 12),
                  _QuickActions(trip: current),
                  const SizedBox(height: 22),
                  if (current != null) ...[
                    SectionTitle(
                      'Current trip',
                      trailing: TextButton(
                        onPressed: () => widget.onOpenTab(1),
                        child: const Text('All trips'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CurrentTripCard(
                      trip: current,
                      onOpenTrip: widget.onOpenTrip,
                    ),
                  ] else
                    EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'No active trip',
                      message:
                          'Every trip on this device is complete. Your hub will '
                          'assign the next run to your vehicle.',
                      action: OutlinedButton(
                        onPressed: () => widget.onOpenTab(1),
                        child: const Text('View completed trips'),
                      ),
                    ),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const SectionTitle('Upcoming trips'),
                    const SizedBox(height: 10),
                    for (final trip in upcoming) ...[
                      UpcomingTripTile(
                        trip: trip,
                        onTap: () => widget.onOpenTrip(trip.code),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 20),
                  const _NoCashNote(),
                  SizedBox(height: 8 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The stored token was rejected, so the session is dropped before the
  /// sign-in screen opens instead of leaving a shell that cannot load trips.
  Future<void> _signInAgain(BuildContext context) async {
    await DriverApi.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated header
// ─────────────────────────────────────────────────────────────────────────────

/// Dark gradient header with a slow moving backdrop: drifting circles, soft
/// pulse rings and small dots floating up. The backdrop never blocks taps and
/// never changes the header size.
class _AnimatedHeader extends StatelessWidget {
  const _AnimatedHeader({
    required this.controller,
    required this.eyebrow,
    required this.greeting,
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.dateText,
    required this.vehicleText,
    required this.unreadNotifications,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  final Animation<double> controller;
  final String eyebrow;
  final String greeting;
  final String name;
  final String subtitle;
  final String initials;
  final String dateText;
  final String vehicleText;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      // Everything animated stays inside this rounded shape.
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pruneLight, VColors.prune],
          ),
        ),
        child: Stack(
          children: [
            // Moving background.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => CustomPaint(
                      painter: _HeaderBackdropPainter(controller.value),
                    ),
                  ),
                ),
              ),
            ),
            // Real content on top.
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VColors.lin,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              greeting,
                              style: const TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _NotificationBell(
                        unreadCount: unreadNotifications,
                        onTap: onOpenNotifications,
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Open profile',
                        child: GestureDetector(
                          onTap: onOpenProfile,
                          behavior: HitTestBehavior.opaque,
                          child: _Avatar(initials: initials),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeaderChip(
                        icon: Icons.event_outlined,
                        text: dateText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderChip(
                          icon: Icons.local_shipping_outlined,
                          text: vehicleText,
                        ),
                      ),
                    ],
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

/// `t` loops from 0.0 to 1.0. Every movement uses whole sine cycles or
/// wrap-around values, so the loop is seamless (no jump when it restarts).
/// Draws only inside its own box, which is the header.
class _HeaderBackdropPainter extends CustomPainter {
  _HeaderBackdropPainter(this.t);

  final double t;

  static const _twoPi = math.pi * 2;

  // x position (0..1 of width), loop phase (0..1), speed (cycles), size, color
  static const _particles = <_Particle>[
    _Particle(0.12, 0.00, 1, 3.0, VColors.lin),
    _Particle(0.28, 0.35, 1, 2.0, VColors.brique),
    _Particle(0.42, 0.70, 1, 2.5, VColors.lin),
    _Particle(0.58, 0.15, 1, 3.5, VColors.brique),
    _Particle(0.72, 0.55, 1, 2.0, VColors.lin),
    _Particle(0.86, 0.85, 1, 3.0, VColors.brique),
    _Particle(0.94, 0.40, 1, 2.0, VColors.lin),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Safety: never paint outside the header.
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;
    final a = t * _twoPi;

    // 1) Soft circles that drift in slow loops.
    canvas.drawCircle(
      Offset(w * 0.88 + math.sin(a) * 18, h * 0.10 + math.cos(a) * 14),
      88,
      Paint()..color = Colors.white.withAlpha(16),
    );

    canvas.drawCircle(
      Offset(w * 0.08 + math.cos(a) * 16, h * 0.92 + math.sin(a) * 12),
      78,
      Paint()..color = VColors.raisin.withAlpha(46),
    );

    // A smaller one moving the opposite way (adds depth).
    canvas.drawCircle(
      Offset(w * 0.55 - math.sin(a) * 22, h * 0.50 + math.cos(a * 2) * 10),
      44,
      Paint()..color = Colors.white.withAlpha(10),
    );

    // 2) Two thin rings that expand and fade (a quiet pulse).
    final ringCenter = Offset(
      w * 0.88 + math.sin(a) * 18,
      h * 0.10 + math.cos(a) * 14,
    );
    for (final phase in const [0.0, 0.5]) {
      final p = (t + phase) % 1.0;
      final radius = 40 + p * 100;
      final alpha = ((1 - p) * 60).round().clamp(0, 255);
      canvas.drawCircle(
        ringCenter,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = VColors.lin.withAlpha(alpha),
      );
    }

    // 3) Small dots floating upward, fading in and out.
    for (final p in _particles) {
      final prog = (t * p.speed + p.phase) % 1.0; // 0 bottom -> 1 top
      final y = h - prog * h;
      final x = w * p.x + math.sin((t * p.speed + p.phase) * _twoPi) * 10;

      // Fade near the bottom and top so dots appear and disappear softly.
      final fade = math.sin(prog * math.pi);
      final alpha = (fade * 140).round().clamp(0, 255);

      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()..color = p.color.withAlpha(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderBackdropPainter old) => old.t != t;
}

class _Particle {
  const _Particle(this.x, this.phase, this.speed, this.size, this.color);

  final double x, phase, size;
  final int speed;
  final Color color;
}

/// Bell in the header with the unread count the server reported.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: unreadCount == 0
          ? 'Notifications'
          : '$unreadCount unread notifications',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                child: Icon(
                  unreadCount == 0
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: VColors.brique,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6B3570),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Small translucent pill in the header: the date and the vehicle.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: VColors.lin, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync strip
// ─────────────────────────────────────────────────────────────────────────────

/// Where the board stands: sample trips, a fresh load from the web, or a
/// failure with a way to retry. Pulling the list down refreshes it too.
class _SyncStrip extends StatelessWidget {
  const _SyncStrip({required this.store, required this.onSignIn});

  final DriverStore store;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final error = store.tripsError;
    if (error != null) {
      return NoticeCard(
        tone: NoticeTone.error,
        icon: Icons.cloud_off_rounded,
        title: store.sessionExpired ? 'Session expired' : 'Trips not refreshed',
        message: error,
        action: TextButton(
          onPressed: store.sessionExpired ? onSignIn : store.refreshTrips,
          child: Text(store.sessionExpired ? 'Sign in' : 'Retry'),
        ),
      );
    }

    if (!store.tripsAreLive) {
      return Row(
        children: [
          if (store.tripsLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VColors.brique,
              ),
            )
          else
            const Icon(
              Icons.cloud_queue_rounded,
              size: 16,
              color: VColors.muted,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              store.tripsLoading
                  ? 'Loading the trips your hub assigned…'
                  : 'These are sample trips. Pull down to load the trips your '
                        'hub assigned to you.',
              style: const TextStyle(
                color: VColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.cloud_done_outlined, size: 16, color: VColors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Updated ${_ago(store.tripsSyncedAt)} from Vendo',
            style: const TextStyle(
              color: VColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: store.tripsLoading ? null : store.refreshTrips,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          style: TextButton.styleFrom(
            foregroundColor: VColors.brique,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// "just now", "4 min ago", "3 h ago", "2 d ago".
String _ago(DateTime? at) {
  if (at == null) return 'just now';
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inSeconds < 45) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
  return '${elapsed.inDays} d ago';
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions
// ─────────────────────────────────────────────────────────────────────────────

/// The three things a driver opens most, aimed at the trip they are on. An
/// action that makes no sense for the current stage stays visible but disabled
/// with the reason, so the row never hides work.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.trip});

  final DriverTrip? trip;

  @override
  Widget build(BuildContext context) {
    final manifestTrip = trip;
    final scheduled = trip?.status == TripStatus.scheduled ? trip : null;
    final inTransit = trip?.status == TripStatus.inTransit ? trip : null;

    void open(Widget screen) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Manifest',
              hint: manifestTrip == null
                  ? 'No active trip'
                  : '${manifestTrip.parcelCount} parcels',
              onTap: manifestTrip == null
                  ? null
                  : () =>
                        open(DriverManifestScreen(tripCode: manifestTrip.code)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan load',
              hint: trip == null
                  ? 'No active trip'
                  : scheduled == null
                  ? 'Already departed'
                  : scheduled.readyToDepart
                  ? 'All scanned'
                  : '${scheduled.originScanned} of ${scheduled.parcelCount}',
              onTap: scheduled == null
                  ? null
                  : () => open(DriverScanScreen(tripCode: scheduled.code)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.route_outlined,
              label: 'Trip status',
              hint: trip == null
                  ? 'No active trip'
                  : inTransit == null
                  ? 'After departure'
                  : 'In transit',
              onTap: inTransit == null
                  ? null
                  : () =>
                        open(DriverTripStatusScreen(tripCode: inTransit.code)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.hint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return VCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? VColors.goldSoft : VColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: enabled ? const Color(0xFF8A6D1A) : VColors.muted,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enabled ? VColors.ink : VColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VColors.muted,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Licence notice
// ─────────────────────────────────────────────────────────────────────────────

/// Shows up when the licence is about to expire, is already expired, or the
/// hub has no expiry on file. Sign-in is refused for an expired licence, so
/// this is the earliest honest warning the driver gets.
class _LicenceNotice extends StatelessWidget {
  const _LicenceNotice({
    required this.daysLeft,
    required this.hasExpiry,
    required this.onOpenProfile,
  });

  final int daysLeft;
  final bool hasExpiry;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final expired = daysLeft < 0;
    final missing = !hasExpiry;
    final accent = expired ? VColors.red : const Color(0xFF8A6D1A);
    final background = expired ? VColors.redSoft : VColors.goldSoft;

    final title = missing
        ? 'No licence expiry on file'
        : expired
        ? 'Licence expired'
        : daysLeft == 0
        ? 'Licence expires today'
        : daysLeft == 1
        ? 'Licence expires tomorrow'
        : 'Licence expires in $daysLeft days';

    final message = missing
        ? 'Your hub needs a valid licence expiry before your next dispatch.'
        : expired
        ? 'The hub cannot dispatch you while the licence is expired. '
              'Renew it and send the new copy to your hub.'
        : 'Renew it before it lapses: an expired licence blocks sign-in and '
              'dispatch.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            expired ? Icons.error_outline_rounded : Icons.badge_outlined,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenProfile,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.store});

  final DriverStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.trips
        .where((trip) => trip.status != TripStatus.completed)
        .length;
    final onboard = store.inTransitTrips.fold<int>(
      0,
      (total, trip) => total + trip.parcelCount,
    );
    final next = store.scheduledTrips.isEmpty
        ? null
        : store.scheduledTrips.first.scheduledDeparture;

    return VCard(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          _Stat(value: '$active', label: 'Active trips'),
          const _StatDivider(),
          _Stat(value: '$onboard', label: 'Parcels onboard'),
          const _StatDivider(),
          _Stat(
            value: next == null ? '—' : timeLabel(next),
            label: 'Next departure',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VColors.prune,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: VColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: VColors.border);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Current trip
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentTripCard extends StatelessWidget {
  const _CurrentTripCard({required this.trip, required this.onOpenTrip});

  final DriverTrip trip;
  final ValueChanged<String> onOpenTrip;

  @override
  Widget build(BuildContext context) {
    final inTransit = trip.status == TripStatus.inTransit;

    return VCard(
      padding: const EdgeInsets.all(16),
      borderColor: inTransit ? const Color(0xFFEBD2C9) : VColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                trip.code,
                style: const TextStyle(
                  color: VColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TripStatusPill(status: trip.status),
            ],
          ),
          const SizedBox(height: 14),
          TripRoute(trip: trip, compact: true),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: inTransit ? VColors.briqueSoft : VColors.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  inTransit
                      ? Icons.local_shipping_outlined
                      : Icons.schedule_rounded,
                  color: inTransit ? VColors.brique : const Color(0xFF8A6D1A),
                  size: 16,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    inTransit
                        ? 'Departed ${timeLabel(trip.departedAt ?? trip.scheduledDeparture)} · ETA ${timeLabel(trip.eta)}'
                        : 'Departs ${dateTimeLabel(trip.scheduledDeparture)}',
                    style: const TextStyle(
                      color: VColors.ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ScanProgress(trip: trip, inTransit: inTransit),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => inTransit
                        ? DriverTripStatusScreen(tripCode: trip.code)
                        : DriverScanScreen(tripCode: trip.code),
                  ),
                );
              },
              child: Text(inTransit ? 'Trip status' : 'Scan parcels'),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onOpenTrip(trip.code),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Trip details'),
            ),
          ),
        ],
      ),
    );
  }
}

/// How many parcels the hub has scanned so far, at the origin before departure
/// and at the destination while the trip is running.
class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.trip, required this.inTransit});

  final DriverTrip trip;
  final bool inTransit;

  @override
  Widget build(BuildContext context) {
    final total = trip.parcelCount;
    final scanned = inTransit ? trip.destinationScanned : trip.originScanned;
    final ratio = total == 0 ? 0.0 : (scanned / total).clamp(0.0, 1.0);

    final done = inTransit ? trip.readyToClose : trip.readyToDepart;
    final tone = done
        ? VColors.green
        : inTransit
        ? VColors.brique
        : const Color(0xFF8A6D1A);

    final label = inTransit
        ? '$scanned of $total received'
        : '$scanned of $total scanned';
    final hint = inTransit
        ? done
              ? 'Every parcel scanned at ${trip.destination}'
              : 'Waiting for destination scans at ${trip.destination}'
        : done
        ? 'All parcels scanned at ${trip.origin}'
        : '${trip.missingOriginScans} '
              '${trip.missingOriginScans == 1 ? 'parcel' : 'parcels'} '
              'still to scan at ${trip.origin}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: VColors.raisin,
            ),
            const SizedBox(width: 6),
            Text(
              '$total parcels',
              style: const TextStyle(
                color: VColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: tone,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: VColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: const TextStyle(
            color: VColors.muted,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _NoCashNote extends StatelessWidget {
  const _NoCashNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: VColors.muted, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Drivers never collect COD cash. Cash stays with the Rider and '
            'travels through the hubs, not through this app.',
            style: TextStyle(color: VColors.muted, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    );
  }
}