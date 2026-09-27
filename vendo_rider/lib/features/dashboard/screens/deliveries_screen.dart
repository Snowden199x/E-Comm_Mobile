import 'package:flutter/material.dart';
import 'package:vendo_rider/features/dashboard/widgets/shared_widgets.dart';

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
    DeliveryData(
      id: '#VD-00120',
      customer: 'Carlo Tan',
      address: '22 España Blvd., Manila',
      status: 'Cancelled',
      amount: '₱ 0',
      time: 'Yesterday, 6:30 PM',
    ),
  ];

  static const _filters = [
    'All',
    'Pending',
    'On the way',
    'Delivered',
    'Cancelled',
  ];

  List<DeliveryData> get _filtered => _activeFilter == 'All'
      ? _allDeliveries
      : _allDeliveries.where((d) => d.status == _activeFilter).toList();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'My Deliveries'),
          const SizedBox(height: 16),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _activeFilter == f
                                  ? const Color(0xFF2D1B3D)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _activeFilter == f
                                    ? const Color(0xFF2D1B3D)
                                    : const Color(0xFFDDDDDD),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: _activeFilter == f
                                    ? Colors.white
                                    : const Color(0xFF555555),
                                fontSize: 12,
                                fontWeight: _activeFilter == f
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No deliveries found.',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                        DeliveryListTile(delivery: _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
