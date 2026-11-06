import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';
import 'package:vendo_rider/features/dashboard/widgets/offline_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo "Warm Courier Kinetic" palette
//  • Prune   → main dark color (header, primary button, key text)
//  • Brique  → terracotta accent (main action tile, highlights)
//  • Lin     → soft gold for earnings on dark
//  • Raisin  → icons and secondary tones
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF3C2143);
  static const pruneDeep = Color(0xFF25142B);
  static const pruneLight = Color(0xFF4A2A52);
  static const brique = Color(0xFFC85A32);
  static const briqueDark = Color(0xFFA23E18);
  static const briqueGlow = Color(0xFFFE8357);
  static const lin = Color(0xFFFFDEAD);
  static const amber = Color(0xFFFABC4D);
  static const raisin = Color(0xFF815488);
  static const lilac = Color(0xFFAA87B0);
  static const online = Color(0xFF22C55E);

  static const background = Color(0xFFFAF7F2);
  static const ink = Color(0xFF1C1C19);
  static const muted = Color(0xFF7D747D);
  static const border = Color(0xFFEDE6DD);
  static const cell = Color(0xFFF6F3EE);

  static const raisinSoft = Color(0x123C2143);
  static const briqueSoft = Color(0xFFF9EAE1);

  static const offline = Color(0xFF9A8F9D);
}

const double _radius = 16;

class HomeScreen extends StatefulWidget {
  /// Opens the assigned parcel work tab.
  final VoidCallback? onOpenParcels;
  final VoidCallback? onOpenEarnings;

  /// Opens the notifications tab.
  final VoidCallback? onOpenNotifications;

  const HomeScreen({
    super.key,
    this.onOpenParcels,
    this.onOpenEarnings,
    this.onOpenNotifications,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _riderName = '';
  String _accruedEarnings = '—';
  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic> _assignmentSummary = {};
  bool _loadingAssignments = true;
  String? _assignmentError;

  // Offline mode: the home totals come from the last saved work when the API
  // cannot be reached, and queued scans upload as soon as it can.
  DateTime? _offlineSince;
  int _pendingCount = 0;
  bool _syncingOffline = false;

  // Drives the header animation (loops forever, 0.0 → 1.0)
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    RiderApi.instance.riderName().then((name) {
      if (mounted) setState(() => _riderName = name ?? 'Rider');
    });
    _refreshAssignments();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _openDeliveryDetails() {
    widget.onOpenParcels?.call();
  }

  Future<void> _refreshAssignments() async {
    if (mounted) setState(() { _loadingAssignments = true; _assignmentError = null; });
    try {
      final data = await RiderApi.instance.assignmentDashboard();
      _applyWork(data);
      if (mounted) setState(() => _offlineSince = null);
      // We just reached Vendo, so send anything saved while offline.
      await _refreshPendingCount();
      await _syncOffline();
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _assignmentError = error.message);
    } catch (_) {
      final cached = await RiderApi.instance.cachedWork();
      if (cached != null) {
        _applyWork(cached.payload);
        if (mounted) setState(() => _offlineSince = cached.cachedAt);
        await _refreshPendingCount();
      } else if (mounted) {
        setState(() => _assignmentError = 'Could not load assigned work. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _loadingAssignments = false);
      // Accrued earnings change whenever work is completed, so they are
      // reloaded every time the work data is refreshed (app start, tab focus,
      // retry, after an offline sync) instead of only once at startup.
      _refreshEarnings();
    }
  }

  void _applyWork(Map<String, dynamic> data) {
    if (!mounted) return;
    final items = (data['assignments'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final summary = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};
    setState(() { _assignments = items; _assignmentSummary = summary; });
  }

  Future<void> _refreshPendingCount() async {
    final count = await RiderApi.instance.pendingOfflineActions();
    if (mounted) setState(() => _pendingCount = count);
  }

  /// Uploads scans and delivery proofs taken without a connection.
  Future<void> _syncOffline() async {
    if (_syncingOffline) return;
    _syncingOffline = true;
    try {
      final report = await RiderApi.instance.syncOfflineActions();
      await _refreshPendingCount();
      if (!mounted) return;
      if (report.synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${report.synced} offline update${report.synced == 1 ? '' : 's'} uploaded.',
            ),
          ),
        );
        await _refreshAssignments();
      } else if (report.hasFailures && report.messages.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(report.messages.first)));
      }
    } catch (_) {
      // Still offline; the queue waits for the next refresh.
    } finally {
      _syncingOffline = false;
    }
  }

  void refreshAssignments() => _refreshAssignments();

  Future<void> _refreshEarnings() async {
    try {
      final data = await RiderApi.instance.earnings();
      final summary = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      final amount = double.tryParse(summary['accrued_total']?.toString() ?? '');
      if (mounted && amount != null) setState(() => _accruedEarnings = '₱${amount.toStringAsFixed(2)}');
    } catch (_) {
      // Keep the last amount we successfully loaded rather than blanking it on
      // a hiccup; only a first load with no data shows the error state.
      if (mounted && _accruedEarnings == '—') {
        setState(() => _accruedEarnings = 'Unavailable');
      }
    }
  }

  void _onAssignParcel() {
    HapticFeedback.selectionClick();
    widget.onOpenParcels?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.background,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderPanel(),
              Padding(
                // The bottom space includes the floating nav bar's height, so
                // the last card can scroll up clear of the bar.
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_offlineSince != null) ...[
                      OfflineBanner(
                        savedAt: _offlineSince,
                        pending: _pendingCount,
                        onRetry: _loadingAssignments
                            ? null
                            : _refreshAssignments,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildActionTiles(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Parcel Overview'),
                    const SizedBox(height: 12),
                    _buildStats(),
                    const SizedBox(height: 24),
                    _buildActiveDelivery(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared flat card ─────────────────────────────────────────────────────
  Widget _card({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D3C2143),
            blurRadius: 16,
            spreadRadius: -2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _C.brique,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _C.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Dark header panel: animated backdrop + greeting + status + earnings ──
  Widget _buildHeaderPanel() {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      // Everything animated stays inside this rounded shape
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.pruneLight, _C.prune, _C.pruneDeep],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Moving background (does not block taps, does not change size)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, _) => CustomPaint(
                      painter: _HeaderBackdropPainter(
                        _bgController.value,
                        topInset,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Real content on top
            Padding(
              padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  const SizedBox(height: 14),
                  _buildStatusPill(),
                  const SizedBox(height: 14),
                  _buildEarningsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        // Avatar with the online dot
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.prune,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x4DCFC3CC), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  color: Color(0xFFE0BAE5),
                  size: 26,
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _C.online,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.prune, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(
                  color: Color(0xFFCFC3CC),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _riderName.isEmpty ? 'Rider' : _riderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Notifications',
          child: Material(
            color: const Color(0x33000000),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onOpenNotifications,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // "Signed in • Rider account" pill with a softly pulsing green dot
  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x663C2143),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33CFC3CC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              // 7 whole pulses per 14s loop → seamless
              final pulse =
                  0.5 + 0.5 * math.sin(_bgController.value * math.pi * 2 * 7);
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _C.online.withAlpha((120 + pulse * 135).round()),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _C.online.withAlpha((pulse * 90).round()),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Signed in',
            style: TextStyle(
              color: Color(0xFFF3F0EB),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '•',
            style: TextStyle(color: Color(0xFFCFC3CC), fontSize: 10),
          ),
          const SizedBox(width: 8),
          const Text(
            'Rider account',
            style: TextStyle(color: Color(0xFFCFC3CC), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Accrued earnings (glass-style card inside the header) ────────────────
  Widget _buildEarningsCard() {
    return Material(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpenEarnings,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: const Color(0x33CFC3CC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Accrued Earnings',
                      style: TextStyle(
                        color: Color(0xFFCFC3CC),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            color: _C.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _C.amber,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _accruedEarnings,
                  style: const TextStyle(
                    color: _C.lin,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick action tiles: the terracotta tile is the main action ───────────
  Widget _buildActionTiles() {
    final loaded = _loadingAssignments
        ? '—'
        : '${_assignmentSummary['loaded'] ?? _assignments.length}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tile 1 — assigned parcels (same action as before)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.brique, _C.briqueDark],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x47C85A32),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(_radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _onAssignParcel,
                  child: Stack(
                    children: [
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0x33FFFFFF),
                          size: 40,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0x26FFFFFF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$loaded now',
                                    style: const TextStyle(
                                      color: _C.briqueDark,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Assigned parcels',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Work from Logistics',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xE6FFDBCF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Tile 2 — earnings (reuses the existing earnings callback)
          Expanded(
            child: _card(
              onTap: widget.onOpenEarnings,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _C.raisinSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _C.prune,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Earnings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.prune,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _accruedEarnings,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Parcel stats: one card, 2×2 tinted cells ─────────────────────────────
  Widget _buildStats() {
    final pickup = _assignmentSummary['pickup'] ?? 0;
    final delivery = _assignmentSummary['delivery'] ?? 0;
    final linehaul = _assignmentSummary['linehaul'] ?? 0;
    return _card(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.inventory_2_outlined,
                  value: _loadingAssignments ? '—' : '${_assignmentSummary['loaded'] ?? _assignments.length}',
                  label: 'Assigned now',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  icon: Icons.assignment_turned_in_outlined,
                  value: _loadingAssignments ? '—' : '$pickup',
                  label: 'Pickup',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.local_shipping_outlined,
                  value: _loadingAssignments ? '—' : '$delivery',
                  label: 'Delivery',
                  highlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  icon: Icons.route_rounded,
                  value: _loadingAssignments ? '—' : '$linehaul',
                  label: 'Linehaul',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Active delivery ──────────────────────────────────────────────────────
  Widget _buildActiveDelivery() {
    final order = _assignments.isEmpty ? null : _assignments.first;
    final stop = order?['stop'] is Map
        ? Map<String, dynamic>.from(order!['stop'] as Map)
        : const <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Active Delivery',
          trailing: (!_loadingAssignments &&
                  _assignmentError == null &&
                  _assignments.isNotEmpty)
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.briqueSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '1 OF ${_assignments.length} PENDING',
                    style: const TextStyle(
                      color: Color(0xFF822801),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (_loadingAssignments)
          _card(child: const LinearProgressIndicator())
        else if (_assignmentError != null)
          _card(
            onTap: _refreshAssignments,
            child: Text('$_assignmentError  Tap to retry.', style: const TextStyle(color: _C.muted)),
          )
        else if (order == null)
          _card(child: const Text('No active assignments yet.', style: TextStyle(color: _C.muted)))
        else
        _card(
          onTap: _openDeliveryDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tracking code + status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRACKING CODE',
                          style: TextStyle(
                            color: _C.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order['tracking_number']?.toString() ?? 'Assigned parcel',
                          style: const TextStyle(
                            color: _C.prune,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _C.briqueSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      riderStageBadge(riderStageOf(order)),
                      style: const TextStyle(
                        color: _C.brique,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF0EDE9)),
              const SizedBox(height: 12),
              // Destination box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.cell,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.pin_drop_outlined,
                        color: _C.brique,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stop['name'] ?? 'Next stop'}',
                            style: const TextStyle(
                              color: _C.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stop['address'] ?? 'Address unavailable'}',
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Current stage
              Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 16, color: _C.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      riderStageTitle(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _C.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Primary plum button (same action as tapping the card)
              Material(
                color: _C.prune,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _openDeliveryDetails,
                  child: const SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.near_me_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'View details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated header backdrop
//
// `t` loops from 0.0 to 1.0. Every movement uses whole sine cycles or
// wrap-around values, so the loop is seamless (no jump when it restarts).
// Layers (back → front):
//   1) aurora glows that drift in slow loops
//   2) radar ripples pulsing out from the avatar
//   3) small glowing dots floating upward
//   4) a soft shimmer that sweeps across the header
// Draws only inside its own box, which is the Prune header.
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderBackdropPainter extends CustomPainter {
  final double t;
  final double topInset;

  _HeaderBackdropPainter(this.t, this.topInset);

  static const _twoPi = math.pi * 2;

  // x position (0..1 of width), loop phase (0..1), speed (cycles), size, color
  static const _particles = <_Particle>[
    _Particle(0.12, 0.00, 1, 3.0, _C.lin),
    _Particle(0.28, 0.35, 1, 2.0, _C.briqueGlow),
    _Particle(0.42, 0.70, 1, 2.5, _C.lin),
    _Particle(0.58, 0.15, 1, 3.5, _C.briqueGlow),
    _Particle(0.72, 0.55, 1, 2.0, Color(0xFFFBD7FF)),
    _Particle(0.86, 0.85, 1, 3.0, _C.briqueGlow),
    _Particle(0.94, 0.40, 1, 2.0, _C.lin),
  ];

  void _glow(Canvas canvas, Offset c, double r, List<Color> colors) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Safety: never paint outside the header
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;
    final a = t * _twoPi;

    // 1) Aurora glows ───────────────────────────────────────────────────────
    // Lilac glow, top right
    _glow(
      canvas,
      Offset(w * 0.95 + math.sin(a) * 30, h * 0.02 + math.cos(a) * 22),
      150,
      const [Color(0x8CAA87B0), Color(0x333C2143), Color(0x00000000)],
    );
    // Terracotta glow, bottom left
    _glow(
      canvas,
      Offset(w * 0.28 + math.cos(a) * 34, h * 0.98 + math.sin(a) * 20),
      135,
      const [Color(0x61FE8357), Color(0x2EA23E18), Color(0x00000000)],
    );
    // Warm amber glow, lower right (moves the opposite way for depth)
    _glow(
      canvas,
      Offset(w * 0.92 - math.sin(a) * 22, h * 0.86 + math.cos(a * 2) * 12),
      105,
      const [Color(0x40FE8357), Color(0x1FBF881A), Color(0x00000000)],
    );

    // 2) Radar ripples from the avatar ──────────────────────────────────────
    final avatar = Offset(16 + 22, topInset + 16 + 22);
    for (var i = 0; i < 2; i++) {
      // 4 whole ripple cycles per loop (3.5s each), second ring half a cycle behind
      final p = (t * 4 + i * 0.5) % 1.0; // 0 → 1
      final radius = 24 + p * 56;
      final alpha = ((1 - p) * 110).round().clamp(0, 255);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (i == 0 ? _C.briqueGlow : _C.lin).withAlpha(alpha);
      canvas.drawCircle(avatar, radius, ringPaint);
    }

    // 3) Small dots floating upward, fading in and out ──────────────────────
    for (final p in _particles) {
      final prog = (t * p.speed + p.phase) % 1.0; // 0 bottom → 1 top
      final y = h - prog * h;
      final x = w * p.x + math.sin((t * p.speed + p.phase) * _twoPi) * 10;

      // Fade near the bottom and top so dots appear/disappear softly
      final fade = math.sin(prog * math.pi); // 0 → 1 → 0
      final alpha = (fade * 190).round().clamp(0, 255);

      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()
          ..color = p.color.withAlpha(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    // 4) Shimmer sweep (2 passes per loop, ~7s each) ────────────────────────
    final s = (t * 2) % 1.0;
    final envelope = math.sin(s * math.pi); // fades in and out
    final bandW = w * 0.45;
    final skew = h * 0.45;
    final x0 = -bandW - skew + s * (w + bandW * 2 + skew);
    final shimmerPath = Path()
      ..moveTo(x0, 0)
      ..lineTo(x0 + bandW, 0)
      ..lineTo(x0 + bandW - skew, h)
      ..lineTo(x0 - skew, h)
      ..close();
    final peak = (envelope * 34).round().clamp(0, 255);
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _C.lin.withAlpha(0),
          _C.lin.withAlpha(peak),
          _C.lin.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(x0 - skew, 0, bandW + skew, h));
    canvas.drawPath(shimmerPath, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _HeaderBackdropPainter old) =>
      old.t != t || old.topInset != topInset;
}

class _Particle {
  final double x, phase, size;
  final int speed;
  final Color color;

  const _Particle(this.x, this.phase, this.speed, this.size, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value, label;

  /// Gives the cell the terracotta treatment (used for Delivery).
  final bool highlight;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _C.cell,
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: const Color(0x33A23E18))
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: highlight ? _C.briqueSoft : _C.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: highlight ? _C.brique : _C.prune,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: highlight ? _C.briqueDark : _C.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: _C.border);
  }
}

class _RouteStop extends StatelessWidget {
  final Color dotColor;
  final String label, address;

  const _RouteStop({
    required this.dotColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _C.muted, fontSize: 11),
              ),
              const SizedBox(height: 1),
              Text(
                address,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}