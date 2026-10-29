import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/auth/screens/login_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the rest of the dashboard
//  • Prune   → dark header, main text
//  • Brique  → accent (active / on the way)
//  • Lin     → soft gold for key numbers on dark
//  • Raisin  → icons and secondary tones
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
  static const goldSoft = Color(0xFFF8F1DC);
}

const double _radius = 16;

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  String? _error;
  String? _name;
  String? _center;
  String? _vehicleType;
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _refresh(showSpinner: true);
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
        });
      }
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
      if (mounted) {
        setState(
          () => _error = 'Cannot reach Vendo. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      if (stages.contains(RiderStage.linehaul)) 'Linehaul',
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
      'Linehaul' => stage == RiderStage.linehaul,
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
                  : _countStage(orders, {RiderStage.forDelivery}),
              deliverLabel: isTruck ? 'Linehaul' : 'Delivery',
            ),
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

  // ── Dark header: title + summary ─────────────────────────────────
  Widget _buildHeader({
    required int total,
    required int pickup,
    required int onTheWay,
    required int deliver,
    required String deliverLabel,
  }) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 12, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.pruneLight, _C.prune],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Deliveries',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh assignments',
                onPressed: _loading ? null : () => _refresh(showSpinner: true),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name == null
                      ? 'Assigned work from Logistics'
                      : 'Hello, $_name',
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total ${total == 1 ? 'parcel' : 'parcels'} in your list',
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 13,
                  ),
                ),
                if (_center != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Logistics hub: $_center',
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Row(
              children: [
                _SummaryItem(value: '$pickup', label: 'Pickup'),
                const _SummaryDivider(),
                _SummaryItem(value: '$onTheWay', label: 'On the way'),
                const _SummaryDivider(),
                _SummaryItem(value: '$deliver', label: deliverLabel),
              ],
            ),
          ),
        ],
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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = filters[i];
          final isActive = filter == activeFilter;

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
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? _C.prune : _C.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? Colors.white : _C.ink,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_countFilter(orders, filter)}',
                    style: TextStyle(
                      color: isActive ? _C.lin : _C.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: items.isEmpty ? 1 : items.length + (_error == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: _C.border),
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
    final tracking = order['tracking_number']?.toString() ?? 'Assigned parcel';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: onTheWay ? _C.brique.withAlpha(80) : _C.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: style.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(style.icon, color: style.fg, size: 22),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            riderStageTitle(order),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onTheWay ? _C.brique : _C.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
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
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      onTheWay
                          ? Icons.local_shipping_outlined
                          : Icons.location_on_outlined,
                      size: 16,
                      color: _C.raisin,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        riderStageSubtitle(order),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: _C.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        riderAssignmentLabel(order),
                        style: const TextStyle(
                          color: _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Text(
                      'View details',
                      style: TextStyle(
                        color: _C.prune,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
      _C.raisin,
      _C.raisinSoft,
      Icons.inventory_2_outlined,
    ),
    RiderStage.onTheWayToBuyer => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.near_me_rounded,
    ),
    RiderStage.linehaul => const _StageStyle(
      _C.prune,
      _C.raisinSoft,
      Icons.local_shipping_outlined,
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

  const _SummaryItem({required this.value, required this.label});

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
              color: _C.lin,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
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
    return Container(width: 1, height: 32, color: const Color(0x26FFFFFF));
  }
}
