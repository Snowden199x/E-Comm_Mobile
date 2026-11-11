import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/auth/screens/login_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_history_screen.dart';
import 'package:vendo_rider/features/dashboard/widgets/offline_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo "Warm Courier Kinetic" palette (same as the Home screen)
//  • Prune   → dark header, primary text, active chip
//  • Brique  → terracotta accent (active / on the way)
//  • Lin     → soft gold for highlights on dark
//  • Raisin  → icons and secondary tones
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF3C2143);
  static const pruneDeep = Color(0xFF25102A);
  static const pruneMid = Color(0xFF33173A);
  static const pruneLight = Color(0xFF3F1E47);
  static const brique = Color(0xFFC85A32);
  static const lin = Color(0xFFFFDEAD);
  static const amberSoft = Color(0xFFFDE68A);
  static const raisin = Color(0xFF815488);
  static const online = Color(0xFF34D399);

  static const background = Color(0xFFFAF7F2);
  static const ink = Color(0xFF1C1C19);
  static const muted = Color(0xFF7D747D);
  static const border = Color(0xFFEDE6DD);

  static const raisinSoft = Color(0xFFF2EAF5);
  static const briqueSoft = Color(0xFFF9EAE1);
  static const goldSoft = Color(0xFFF8F1DC);
}

const double _radius = 16;
const double _cardRadius = 20;

// Tracking codes use a monospace face so 0/O and 1/I are never confused.
// If JetBrains Mono is not bundled in the app, Flutter falls back to monospace.
const List<String> _monoFallback = ['monospace', 'Courier'];

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => DeliveriesScreenState();
}

class DeliveriesScreenState extends State<DeliveriesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  String? _error;
  String? _name;
  String? _center;
  String? _vehicleType;
  String _activeFilter = 'All';

  // Offline mode: when the API cannot be reached the list falls back to the
  // last saved work on this device, and scans queue until the signal returns.
  DateTime? _offlineSince;
  int _pendingCount = 0;
  bool _syncingOffline = false;

  // Drives the header animation (loops forever, 0.0 → 1.0). Created on first
  // use rather than in initState, so a rebuild that beats initState (or a hot
  // reload that skips it) can never read it uninitialized.
  AnimationController? _bg;
  AnimationController get _bgController => _bg ??= AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _refresh(showSpinner: true);
  }

  @override
  void dispose() {
    _bg?.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showSpinner = false}) async {
    if (mounted) {
      setState(() {
        if (showSpinner) _loading = true;
        _error = null;
      });
    }
    try {
      final work = await RiderApi.instance.assignments();
      final name = await RiderApi.instance.riderName();
      final center = await RiderApi.instance.centerName();
      final vehicleType = await RiderApi.instance.riderVehicleType();
      if (mounted) {
        setState(() {
          _assignments = work;
          _name = name;
          _center = center;
          _vehicleType = vehicleType;
          _offlineSince = null;
        });
      }
      // We just reached Vendo, so send anything saved while offline.
      await _refreshPendingCount();
      await _syncOffline();
    } on RiderApiException catch (error) {
      if (mounted && (error.statusCode == 401 || error.statusCode == 403)) {
        await RiderApi.instance.clearSession();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      // No connection: show the work saved on this device instead of an error.
      final cached = await RiderApi.instance.cachedWork();
      final name = await RiderApi.instance.riderName();
      final center = await RiderApi.instance.centerName();
      final vehicleType = await RiderApi.instance.riderVehicleType();
      if (!mounted) return;
      if (cached == null) {
        setState(() {
          _error = 'Cannot reach Vendo and no saved work is on this device yet.';
        });
        return;
      }
      final work = (cached.payload['assignments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() {
        _assignments = work;
        _name = name;
        _center = center;
        _vehicleType = vehicleType;
        _offlineSince = cached.cachedAt;
        _error = null;
      });
      await _refreshPendingCount();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        await _refresh();
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

  /// Reloads assigned work when the Parcels tab is opened or a new
  /// assignment notification arrives.
  Future<void> refreshAssignments() => _refresh();

  List<Map<String, dynamic>> get _visible => _assignments
      .where((order) => riderSupportsAssignment(order, _vehicleType))
      .toList();

  int _countStage(List<Map<String, dynamic>> orders, Set<RiderStage> stages) =>
      orders.where((order) => stages.contains(riderStageOf(order))).length;

  List<String> _filtersFor(List<Map<String, dynamic>> orders) {
    final stages = orders.map(riderStageOf).toSet();
    return [
      'All',
      if (stages.contains(RiderStage.readyForPickup)) 'Pickup',
      if (stages.contains(RiderStage.onTheWayToHub) ||
          stages.contains(RiderStage.onTheWayToBuyer))
        'On the way',
      if (stages.contains(RiderStage.forDelivery)) 'Delivery',
      if (stages.contains(RiderStage.returnPickup) ||
          stages.contains(RiderStage.returnHandover))
        'Return',
      if (stages.contains(RiderStage.linehaul)) 'Linehaul',
      if (stages.contains(RiderStage.deliveryFailed)) 'Failed',
    ];
  }

  bool _matchesFilter(Map<String, dynamic> order, String filter) {
    final stage = riderStageOf(order);
    return switch (filter) {
      'Pickup' => stage == RiderStage.readyForPickup,
      'On the way' =>
        stage == RiderStage.onTheWayToHub ||
            stage == RiderStage.onTheWayToBuyer,
      'Delivery' => stage == RiderStage.forDelivery,
      'Return' =>
        stage == RiderStage.returnPickup ||
            stage == RiderStage.returnHandover,
      'Linehaul' => stage == RiderStage.linehaul,
      'Failed' => stage == RiderStage.deliveryFailed,
      _ => true,
    };
  }

  int _countFilter(List<Map<String, dynamic>> orders, String filter) =>
      orders.where((order) => _matchesFilter(order, filter)).length;

  Future<void> _openDetails(Map<String, dynamic> order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeliveryDetailScreen(order: order)),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _visible;
    final filters = _filtersFor(orders);
    final activeFilter = filters.contains(_activeFilter)
        ? _activeFilter
        : 'All';
    final filtered = orders
        .where((order) => _matchesFilter(order, activeFilter))
        .toList();
    final onTheWay = _countStage(orders, {
      RiderStage.onTheWayToHub,
      RiderStage.onTheWayToBuyer,
    });
    final isTruck = _vehicleType == 'Truck';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              total: orders.length,
              pickup: _countStage(orders, {RiderStage.readyForPickup}),
              onTheWay: onTheWay,
              deliver: isTruck
                  ? _countStage(orders, {RiderStage.linehaul})
                  : _countStage(orders, {
                      RiderStage.forDelivery,
                      RiderStage.returnPickup,
                      RiderStage.returnHandover,
                    }),
              deliverLabel: isTruck ? 'Linehaul' : 'Delivery',
            ),
            if (_offlineSince != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OfflineBanner(
                  savedAt: _offlineSince,
                  pending: _pendingCount,
                  onRetry: _loading
                      ? null
                      : () => _refresh(showSpinner: true),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (filters.length > 1)
              _buildFilters(filters, orders, activeFilter),
            const SizedBox(height: 12),
            Expanded(
              child: _loading && _assignments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _assignments.isEmpty
                  ? _buildErrorState()
                  : _buildList(filtered, activeFilter),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dark header: animated backdrop + title + summary ─────────────
  Widget _buildHeader({
    required int total,
    required int pickup,
    required int onTheWay,
    required int deliver,
    required String deliverLabel,
  }) {
    final topInset = MediaQuery.of(context).padding.top;
    final isOffline = _offlineSince != null;

    return ClipRRect(
      // Everything animated stays inside this rounded shape
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.pruneDeep, _C.pruneMid, _C.pruneLight],
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
                      painter: _HeaderBackdropPainter(_bgController.value),
                    ),
                  ),
                ),
              ),
            ),
            // Real content on top
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'My Deliveries',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusPill(isOffline),
                      const Spacer(),
                      _buildHistoryButton(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _name == null
                              ? 'Assigned work from Logistics'
                              : 'Hello, ',
                        ),
                        if (_name != null)
                          TextSpan(
                            text: _name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const TextSpan(
                          text: '  •  ',
                          style: TextStyle(color: Color(0x4DFFFFFF)),
                        ),
                        TextSpan(
                          text:
                              '$total ${total == 1 ? 'parcel' : 'parcels'} in your list',
                          style: const TextStyle(
                            color: _C.amberSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 14,
                    ),
                  ),
                  if (_center != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'HUB: '),
                            TextSpan(
                              text: _center!.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0x80FFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x12FFFFFF),
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Row(
                      children: [
                        _SummaryItem(value: '$pickup', label: 'Pickup'),
                        const _SummaryDivider(),
                        _SummaryItem(value: '$onTheWay', label: 'On the way'),
                        const _SummaryDivider(),
                        _SummaryItem(
                          value: '$deliver',
                          label: deliverLabel,
                          highlight: true,
                          showDot: deliver > 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "ACTIVE" pill with a softly pulsing dot (shows OFFLINE when using saved work)
  Widget _buildStatusPill(bool isOffline) {
    final dotColor = isOffline ? const Color(0xFFFBBF24) : _C.online;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AFFFFFF)),
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
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor.withAlpha((120 + pulse * 135).round()),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withAlpha((pulse * 90).round()),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            isOffline ? 'OFFLINE' : 'ACTIVE',
            style: const TextStyle(
              color: _C.amberSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // Round glass history button: the parcels completed on a chosen day.
  Widget _buildHistoryButton() {
    return Tooltip(
      message: 'Delivery history',
      child: Material(
        color: const Color(0x1AFFFFFF),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeliveryHistoryScreen()),
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter chips with counts ─────────────────────────────────────
  Widget _buildFilters(
    List<String> filters,
    List<Map<String, dynamic>> orders,
    String activeFilter,
  ) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final filter = filters[i];
          final isActive = filter == activeFilter;
          final count = _countFilter(orders, filter);

          return GestureDetector(
            onTap: () {
              if (filter == activeFilter) return;
              HapticFeedback.selectionClick();
              setState(() => _activeFilter = filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? _C.prune : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isActive ? _C.prune : _C.border),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? const Color(0x263C2143)
                        : const Color(0x0A3C2143),
                    blurRadius: isActive ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? Colors.white : _C.ink,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (count > 0 || isActive)
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0x33FFFFFF)
                            : const Color(0xFFF0EDE9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isActive ? Colors.white : _C.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Color(0xFFA8A0AB),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── List (or truthful loading / error / empty state) ─────────────
  Widget _buildList(List<Map<String, dynamic>> items, String activeFilter) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: items.isEmpty ? 1 : items.length + (_error == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) {
          if (items.isEmpty) {
            return _error == null ? _buildEmptyState() : _buildErrorState();
          }
          if (_error != null && index == 0) return _buildErrorBanner();
          final item = items[_error == null ? index : index - 1];
          return _DeliveryCard(order: item, onTap: () => _openDetails(item));
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: _C.raisinSoft,
              child: Icon(
                Icons.inventory_2_outlined,
                color: _C.raisin,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No parcels here',
              style: TextStyle(
                color: _C.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _vehicleType == 'Truck'
                  ? 'No truck linehaul assignments yet. The Main Hub assigns a Truck Rider after sorting the parcel.'
                  : 'No pickup or delivery assignments yet. Pull down to refresh.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? 'Could not load assignments.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.ink),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _refresh(showSpinner: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.briqueSoft,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _C.brique.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _C.brique, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$_error Showing the last loaded assignments.',
              style: const TextStyle(color: _C.ink, fontSize: 12, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () => _refresh(showSpinner: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated header backdrop
//
// `t` loops from 0.0 to 1.0. Every movement uses whole sine cycles or
// wrap-around values, so the loop is seamless (no jump when it restarts).
// Layers (back → front):
//   1) aurora glows (magenta, amber, violet) drifting in slow loops
//   2) three big ripple rings pulsing out from the top centre
//   3) small glowing amber dots bobbing around
//   4) a soft shimmer that sweeps across the header
// Draws only inside its own box, which is the Prune header.
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderBackdropPainter extends CustomPainter {
  final double t;

  _HeaderBackdropPainter(this.t);

  static const _twoPi = math.pi * 2;

  // x (0..1 of width), y (0..1 of height), loop cycles, phase (0..1), size, color
  static const _dots = <_Dot>[
    _Dot(0.10, 0.30, 1, 0.00, 2.4, Color(0xFFFCD34D)),
    _Dot(0.88, 0.40, 2, 0.30, 3.0, Color(0xFFFBBF24)),
    _Dot(0.35, 0.62, 3, 0.55, 1.8, Color(0xFFFDE68A)),
    _Dot(0.92, 0.55, 1, 0.80, 2.4, Color(0xFFFB923C)),
    _Dot(0.18, 0.80, 2, 0.15, 2.4, Color(0xFFFCD34D)),
    _Dot(0.64, 0.22, 3, 0.45, 2.0, Color(0xFFFDE68A)),
  ];

  void _glow(Canvas canvas, Offset c, double r, List<Color> colors) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 0.5, 1.0],
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
    // Magenta glow, top left
    _glow(
      canvas,
      Offset(w * 0.02 + math.sin(a) * 36, h * 0.02 + math.cos(a) * 26),
      190,
      const [Color(0x73D946EF), Color(0x40F43F5E), Color(0x00000000)],
    );
    // Amber glow, right side
    _glow(
      canvas,
      Offset(w * 1.0 - math.cos(a) * 34, h * 0.40 + math.sin(a) * 28),
      190,
      const [Color(0x66FBBF24), Color(0x33F97316), Color(0x00000000)],
    );
    // Violet glow, bottom (moves with a double cycle for depth)
    _glow(
      canvas,
      Offset(w * 0.33 + math.sin(a * 2) * 26, h * 1.0 + math.cos(a) * 14),
      150,
      const [Color(0x66A855F7), Color(0x33814088), Color(0x00000000)],
    );

    // 2) Three big ripples from the top centre ──────────────────────────────
    final center = Offset(w * 0.5, -8);
    const ringColors = [Color(0xFFFCD34D), Color(0xFFE879F9), Color(0xFFD8B4FE)];
    for (var i = 0; i < 3; i++) {
      // 4 whole ripple cycles per loop (3.5s each), rings spaced a third apart
      final p = (t * 4 + i / 3) % 1.0; // 0 → 1
      final radius = 30 + p * 210;
      final alpha = ((1 - p) * 85).round().clamp(0, 255);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = ringColors[i].withAlpha(alpha),
      );
    }

    // 3) Glowing dots bobbing in place, fading in and out ───────────────────
    for (final d in _dots) {
      final ph = t * d.cycles + d.phase;
      final x = w * d.x + math.sin(ph * _twoPi) * 12;
      final y = h * d.y + math.cos(ph * _twoPi) * 16;
      final alpha = (110 + 120 * (0.5 + 0.5 * math.sin(ph * _twoPi))).round();
      final pos = Offset(x, y);
      // soft halo
      canvas.drawCircle(
        pos,
        d.size * 2.6,
        Paint()
          ..color = d.color.withAlpha((alpha * 0.35).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(pos, d.size, Paint()..color = d.color.withAlpha(alpha));
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
    final peak = (envelope * 30).round().clamp(0, 255);
    canvas.drawPath(
      shimmerPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withAlpha(0),
            Colors.white.withAlpha(peak),
            Colors.white.withAlpha(0),
          ],
        ).createShader(Rect.fromLTWH(x0 - skew, 0, bandW + skew, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderBackdropPainter old) => old.t != t;
}

class _Dot {
  final double x, y, phase, size;
  final int cycles;
  final Color color;

  const _Dot(this.x, this.y, this.cycles, this.phase, this.size, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// One assigned parcel card
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _DeliveryCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stage = riderStageOf(order);
    final style = _StageStyle.of(stage);
    final onTheWay =
        stage == RiderStage.onTheWayToHub ||
        stage == RiderStage.onTheWayToBuyer;
    // A failed parcel is the one the daily cutoff closed on: it stays in the
    // list until the rider reschedules it, so it is highlighted, not buried.
    final failed = stage == RiderStage.deliveryFailed;
    final window = order['delivery_window'];
    final cutoff = window is Map
        ? (window['cutoff_label']?.toString().trim() ?? '')
        : '';
    // Set once the parcel has a booked reattempt (e.g. after a reschedule).
    final scheduledFor = window is Map
        ? (window['scheduled_for_label']?.toString().trim() ?? '')
        : '';
    final tracking = order['tracking_number']?.toString() ?? 'Assigned parcel';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: failed
              ? _C.brique.withAlpha(150)
              : onTheWay
              ? _C.brique.withAlpha(90)
              : _C.border,
        ),
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
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: style.fg.withAlpha(26)),
                      ),
                      child: Icon(style.icon, color: style.fg, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tracking,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'JetBrains Mono',
                              fontFamilyFallback: _monoFallback,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            riderStageTitle(order),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onTheWay ? _C.brique : _C.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: style.fg.withAlpha(30)),
                      ),
                      child: Text(
                        riderStageBadge(stage),
                        style: TextStyle(
                          color: style.fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (scheduledFor.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _C.raisinSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.prune.withAlpha(30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          size: 14,
                          color: _C.prune,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Scheduled for $scheduledFor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.prune,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (failed) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _C.briqueSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.brique.withAlpha(50)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.timer_off_outlined,
                          size: 16,
                          color: _C.brique,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Missed the ${cutoff.isEmpty ? '5:00 PM' : cutoff} cutoff. Reschedule this parcel to try again.',
                            style: const TextStyle(
                              color: _C.brique,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: const BoxDecoration(
                        color: _C.briqueSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        onTheWay
                            ? Icons.local_shipping_outlined
                            : Icons.location_on_outlined,
                        size: 13,
                        color: _C.brique,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        riderStageSubtitle(order),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF0EDE9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        riderAssignmentLabel(order).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFA8A0AB),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Text(
                      'View details',
                      style: TextStyle(
                        color: _C.prune,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _C.prune,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageStyle {
  final Color fg, bg;
  final IconData icon;

  const _StageStyle(this.fg, this.bg, this.icon);

  static _StageStyle of(RiderStage stage) => switch (stage) {
    RiderStage.readyForPickup => const _StageStyle(
      Color(0xFF8A6D1A),
      _C.goldSoft,
      Icons.shopping_bag_outlined,
    ),
    RiderStage.onTheWayToHub => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.local_shipping_rounded,
    ),
    RiderStage.forDelivery => const _StageStyle(
      _C.prune,
      _C.raisinSoft,
      Icons.inventory_2_outlined,
    ),
    RiderStage.onTheWayToBuyer => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.near_me_rounded,
    ),
    RiderStage.returnPickup => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.replay_rounded,
    ),
    RiderStage.returnHandover => const _StageStyle(
      _C.prune,
      _C.raisinSoft,
      Icons.assignment_return_rounded,
    ),
    RiderStage.linehaul => const _StageStyle(
      _C.prune,
      _C.raisinSoft,
      Icons.local_shipping_outlined,
    ),
    RiderStage.delivered => const _StageStyle(
      Color(0xFF1A9B5A),
      Color(0xFFE8F5E9),
      Icons.check_circle_rounded,
    ),
    RiderStage.deliveryFailed => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.timer_off_outlined,
    ),
    RiderStage.other => const _StageStyle(
      _C.muted,
      Color(0xFFF1EEF1),
      Icons.inventory_2_outlined,
    ),
  };
}

class _SummaryItem extends StatelessWidget {
  final String value, label;

  /// The last cell is brighter, like in the reference (the main work count).
  final bool highlight;
  final bool showDot;

  const _SummaryItem({
    required this.value,
    required this.label,
    this.highlight = false,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight ? Colors.white : const Color(0xCCFFFFFF),
                    fontSize: 22,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              if (showDot) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _C.online,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? Colors.white : const Color(0x99FFFFFF),
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: const Color(0x1AFFFFFF));
  }
}