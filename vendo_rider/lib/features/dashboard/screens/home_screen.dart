import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';
import 'package:vendo_rider/features/work/screens/rider_work_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo brand palette (from the logo)
//  • Prune  → main dark color (header, text)
//  • Brique → ONE accent: main button + small highlights
//  • Lin    → soft gold for key numbers on dark
//  • Raisin → icons and secondary tones
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF412143);
  static const pruneLight = Color(0xFF55295A);
  static const brique = Color(0xFFBF5E40);
  static const lin = Color(0xFFDBC583);
  static const raisin = Color(0xFF815488);

  static const background = Color(0xFFFAF7F5);
  static const ink = Color(0xFF2A1B2C);
  static const muted = Color(0xFF8C8290);
  static const border = Color(0xFFECE6EA);

  static const raisinSoft = Color(0xFFF4EDF5);
  static const briqueSoft = Color(0xFFF8EAE5);

  static const offline = Color(0xFF9A8F9D);
}

const double _radius = 16;

class HomeScreen extends StatefulWidget {
  /// Called when the rider taps the earnings card.
  /// DashboardScreen uses this to jump to the Earnings tab.
  final VoidCallback? onViewEarnings;

  const HomeScreen({super.key, this.onViewEarnings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  String _riderName = '';

  // Drives the header animation (loops forever, 0.0 → 1.0)
  late final AnimationController _bgController;

  // Placeholder until the API returns the real rider ID
  static const _riderId = 'RID-45821';

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

  void _toggleOnline() {
    HapticFeedback.selectionClick();
    setState(() => _isOnline = !_isOnline);
  }

  void _openDeliveryDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryDetailScreen()),
    );
  }

  void _onAssignParcel() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RiderWorkScreen()),
    );
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAssignParcelButton(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Parcel Overview'),
                    const SizedBox(height: 12),
                    _buildStats(),
                    const SizedBox(height: 28),
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

  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _C.brique,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _C.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Dark header panel: animated backdrop + greeting + status + earnings ──
  Widget _buildHeaderPanel() {
    final topInset = MediaQuery.of(context).padding.top;
    final dotColor = _isOnline ? _C.lin : _C.offline;

    return ClipRRect(
      // Everything animated stays inside this rounded shape
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
            colors: [_C.pruneLight, _C.prune],
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
              padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(dotColor),
                  const SizedBox(height: 22),
                  _buildEarningsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(Color dotColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 14,
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
                ),
              ),
              const SizedBox(height: 12),
              // Online status pill: tap to switch
              GestureDetector(
                onTap: _toggleOnline,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x26FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 10,
                        color: const Color(0x40FFFFFF),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        _riderId,
                        style: TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: _C.lin,
            shape: BoxShape.circle,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _C.raisin,
              shape: BoxShape.circle,
            ),
            // Swap this Icon for an Image / NetworkImage when you have photos
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  // ── Today's earnings (glass-style card inside the header) ────────────────
  Widget _buildEarningsCard() {
    return Material(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onViewEarnings,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Earnings",
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '₱ 1,250.00',
                      style: TextStyle(
                        color: _C.lin,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main action: the one thing in the accent color ───────────────────────
  Widget _buildAssignParcelButton() {
    return Material(
      color: _C.brique,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _onAssignParcel,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 30,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Parcel to Me',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Scan a QR or barcode',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Parcel stats: one card, four cells, thin dividers ────────────────────
  Widget _buildStats() {
    return _card(
      padding: EdgeInsets.zero,
      child: const Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.inventory_2_outlined,
                  value: '12',
                  label: 'Assigned',
                ),
              ),
              _VDivider(),
              Expanded(
                child: _StatCell(
                  icon: Icons.assignment_turned_in_outlined,
                  value: '8',
                  label: 'Picked Up',
                ),
              ),
            ],
          ),
          Divider(height: 1, thickness: 1, color: _C.border),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.local_shipping_outlined,
                  value: '4',
                  label: 'In Transit',
                ),
              ),
              _VDivider(),
              Expanded(
                child: _StatCell(
                  icon: Icons.check_circle_outline_rounded,
                  value: '3',
                  label: 'Delivered',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Active Delivery'),
        const SizedBox(height: 12),
        _card(
          onTap: _openDeliveryDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '#VD-00125',
                      style: TextStyle(
                        color: _C.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _C.briqueSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'On the way',
                      style: TextStyle(
                        color: _C.brique,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _RouteStop(
                dotColor: _C.raisin,
                label: 'Pickup',
                address: 'Vendo Warehouse, Quezon City',
              ),
              Container(
                width: 1.5,
                height: 16,
                margin: const EdgeInsets.only(left: 4.25, top: 3, bottom: 3),
                color: _C.border,
              ),
              const _RouteStop(
                dotColor: _C.brique,
                label: 'Dropoff',
                address: '88 Del Monte Ave., Brgy. Manresa, QC',
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: _C.border),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.near_me_outlined, size: 16, color: _C.muted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '2.2 km · 8 min away',
                      style: TextStyle(color: _C.muted, fontSize: 13),
                    ),
                  ),
                  Text(
                    'View details',
                    style: TextStyle(
                      color: _C.prune,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _C.prune, size: 20),
                ],
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
// Draws only inside its own box, which is the Prune header.
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderBackdropPainter extends CustomPainter {
  final double t;

  _HeaderBackdropPainter(this.t);

  static const _twoPi = math.pi * 2;

  // x position (0..1 of width), loop phase (0..1), speed (cycles), size, color
  static const _particles = <_Particle>[
    _Particle(0.12, 0.00, 1, 3.0, _C.lin),
    _Particle(0.28, 0.35, 1, 2.0, _C.brique),
    _Particle(0.42, 0.70, 1, 2.5, _C.lin),
    _Particle(0.58, 0.15, 1, 3.5, _C.brique),
    _Particle(0.72, 0.55, 1, 2.0, _C.lin),
    _Particle(0.86, 0.85, 1, 3.0, _C.brique),
    _Particle(0.94, 0.40, 1, 2.0, _C.lin),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Safety: never paint outside the header
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;
    final a = t * _twoPi;

    // 1) Two big soft circles that drift in slow loops
    final bigPaint = Paint()..color = Colors.white.withAlpha(16);
    canvas.drawCircle(
      Offset(w * 0.88 + math.sin(a) * 18, h * 0.10 + math.cos(a) * 14),
      88,
      bigPaint,
    );

    final raisinPaint = Paint()..color = _C.raisin.withAlpha(46);
    canvas.drawCircle(
      Offset(w * 0.08 + math.cos(a) * 16, h * 0.92 + math.sin(a) * 12),
      78,
      raisinPaint,
    );

    // A third, smaller one moving the opposite way (adds depth)
    final smallPaint = Paint()..color = Colors.white.withAlpha(10);
    canvas.drawCircle(
      Offset(w * 0.55 - math.sin(a) * 22, h * 0.50 + math.cos(a * 2) * 10),
      44,
      smallPaint,
    );

    // 2) Two thin rings that expand and fade (like a quiet pulse)
    final ringCenter = Offset(
      w * 0.88 + math.sin(a) * 18,
      h * 0.10 + math.cos(a) * 14,
    );
    for (final phase in const [0.0, 0.5]) {
      final p = (t + phase) % 1.0; // 0 → 1
      final radius = 40 + p * 100;
      final alpha = ((1 - p) * 60).round().clamp(0, 255);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _C.lin.withAlpha(alpha);
      canvas.drawCircle(ringCenter, radius, ringPaint);
    }

    // 3) Small dots floating upward, fading in and out
    for (final p in _particles) {
      final prog = (t * p.speed + p.phase) % 1.0; // 0 bottom → 1 top
      final y = h - prog * h;
      final x = w * p.x + math.sin((t * p.speed + p.phase) * _twoPi) * 10;

      // Fade near the bottom and top so dots appear/disappear softly
      final fade = math.sin(prog * math.pi); // 0 → 1 → 0
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

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _C.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _C.raisin, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _C.prune,
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
