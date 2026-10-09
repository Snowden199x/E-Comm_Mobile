import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';
import 'package:vendo_rider/features/dashboard/widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as home_screen.dart
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
}

const double _radius = 16;

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  String _activeFilter = 'All';

  static const _allDeliveries = [
    DeliveryData(
      id: '#VD-00125',
      customer: 'Pedro Bautista',
      address: '88 Del Monte Ave., QC',
      status: 'On the way',
      amount: '₱ 85',
      time: 'Today, 11:30 AM',
    ),
    DeliveryData(
      id: '#VD-00124',
      customer: 'Maria Santos',
      address: '45 Rizal St., QC',
      status: 'Delivered',
      amount: '₱ 80',
      time: 'Today, 10:42 AM',
    ),
    DeliveryData(
      id: '#VD-00123',
      customer: 'Jose Reyes',
      address: '12 Mabini Ave., Manila',
      status: 'Delivered',
      amount: '₱ 95',
      time: 'Today, 9:15 AM',
    ),
    DeliveryData(
      id: '#VD-00122',
      customer: 'Ana Cruz',
      address: '7 Lapu-Lapu St., Pasay',
      status: 'Delivered',
      amount: '₱ 70',
      time: 'Today, 8:05 AM',
    ),
    DeliveryData(
      id: '#VD-00121',
      customer: 'Ben Reyes',
      address: '3 Katipunan Ave., QC',
      status: 'Pending',
      amount: '₱ 90',
      time: 'Today, 7:50 AM',
    ),
  ];

  static const _filters = ['All', 'Pending', 'On the way', 'Delivered'];

  List<DeliveryData> get _filtered => _activeFilter == 'All'
      ? _allDeliveries
      : _allDeliveries.where((d) => d.status == _activeFilter).toList();

  int _count(String filter) => filter == 'All'
      ? _allDeliveries.length
      : _allDeliveries.where((d) => d.status == filter).length;

  // Every order in the list counts toward today's work
  int get _workTotal => _allDeliveries.length;

  double get _progress =>
      _workTotal == 0 ? 0 : _count('Delivered') / _workTotal;

  void _selectFilter(String filter) {
    if (filter == _activeFilter) return;
    HapticFeedback.selectionClick();
    setState(() => _activeFilter = filter);
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  // ── Dark header: title + quick summary ───────────────────────────────────
  Widget _buildHeader() {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 22),
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
          const Text(
            'My Deliveries',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_allDeliveries.length} orders in your list',
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          // Glass-style summary strip (same look as the earnings card on Home)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Column(
              children: [
                // The three steps of a delivery, in order
                Row(
                  children: [
                    _SummaryItem(
                      value: '${_count('Pending')}',
                      label: 'Pending',
                    ),
                    const _SummaryDivider(),
                    _SummaryItem(
                      value: '${_count('On the way')}',
                      label: 'On the way',
                    ),
                    const _SummaryDivider(),
                    _SummaryItem(
                      value: '${_count('Delivered')}',
                      label: 'Delivered',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Simple progress: how many are done out of all active orders
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Delivery progress',
                              style: TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${_count('Delivered')} of $_workTotal delivered',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                          backgroundColor: const Color(0x26FFFFFF),
                          valueColor: const AlwaysStoppedAnimation(_C.lin),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips with counts ─────────────────────────────────────────────
  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = _filters[i];
          final isActive = filter == _activeFilter;

          return GestureDetector(
            onTap: () => _selectFilter(filter),
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
                    '${_count(filter)}',
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

  // ── List (or friendly empty state) ───────────────────────────────────────
  Widget _buildList() {
    final items = _filtered;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: items.isEmpty
          ? const _EmptyState(key: ValueKey('empty'))
          : ListView.separated(
              key: ValueKey(_activeFilter),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _DeliveryCard(delivery: items[i], onTap: _openDetails),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status look (color + icon) for each delivery status
// ─────────────────────────────────────────────────────────────────────────────
class _StatusStyle {
  final Color fg, bg;
  final IconData icon;

  const _StatusStyle(this.fg, this.bg, this.icon);

  static _StatusStyle of(String status) {
    switch (status) {
      case 'On the way':
        return const _StatusStyle(
          _C.brique,
          _C.briqueSoft,
          Icons.local_shipping_rounded,
        );
      case 'Delivered':
        return const _StatusStyle(
          _C.raisin,
          _C.raisinSoft,
          Icons.check_circle_rounded,
        );
      case 'Pending':
        return const _StatusStyle(
          Color(0xFF8A6D1A),
          Color(0xFFF8F1DC),
          Icons.schedule_rounded,
        );
      default: // Fallback for any unknown status
        return const _StatusStyle(
          _C.muted,
          Color(0xFFF1EEF1),
          Icons.help_outline_rounded,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One delivery card
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryCard extends StatelessWidget {
  final DeliveryData delivery;
  final VoidCallback onTap;

  const _DeliveryCard({required this.delivery, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = _StatusStyle.of(delivery.status);

    return Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: status icon, order id + customer, status chip
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
                            delivery.id,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            delivery.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
                        delivery.status,
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

                // Address
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: _C.raisin,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        delivery.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: _C.border),
                const SizedBox(height: 12),

                // Bottom: time and fee
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: _C.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        delivery.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _C.muted, fontSize: 12),
                      ),
                    ),
                    Text(
                      delivery.amount,
                      style: const TextStyle(
                        color: _C.prune,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _C.muted,
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

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: _C.raisinSoft,
            child: Icon(Icons.inventory_2_outlined, color: _C.raisin, size: 30),
          ),
          SizedBox(height: 16),
          Text(
            'No deliveries here',
            style: TextStyle(
              color: _C.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try another filter to see more orders.',
            style: TextStyle(color: _C.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}