import 'package:flutter/material.dart';
import 'package:vendo_rider/features/dashboard/widgets/shared_widgets.dart';
import 'package:vendo_rider/features/dashboard/screens/delivery_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = true;

  static const _recentDeliveries = [
    DeliveryData(
      id: '#VD-00124',
      customer: 'Maria Santos',
      address: '45 Rizal St., Brgy. Pag-asa, QC',
      status: 'Delivered',
      amount: '₱ 80',
      time: '10:42 AM',
    ),
    DeliveryData(
      id: '#VD-00123',
      customer: 'Jose Reyes',
      address: '12 Mabini Ave., Sampaloc, Manila',
      status: 'Delivered',
      amount: '₱ 95',
      time: '9:15 AM',
    ),
    DeliveryData(
      id: '#VD-00122',
      customer: 'Ana Cruz',
      address: '7 Lapu-Lapu St., Pasay City',
      status: 'Delivered',
      amount: '₱ 70',
      time: '8:05 AM',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B1F52), Color(0xFF2A1440)],
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good morning,',
                              style: TextStyle(
                                color: Color(0xAAFFFFFF),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Juan Dela Cruz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification bell
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8873A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Online / Offline toggle
                  GestureDetector(
                    onTap: () => setState(() => _isOnline = !_isOnline),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? const Color(0xFF2ECC71)
                                  : const Color(0xFF888888),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.two_wheeler_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isOnline
                                      ? 'You are Online'
                                      : 'You are Offline',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _isOnline
                                      ? 'Ready to accept deliveries'
                                      : 'Tap to go online',
                                  style: const TextStyle(
                                    color: Color(0xAAFFFFFF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Animated toggle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 50,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? const Color(0xFF2ECC71)
                                  : const Color(0xFF666666),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 250),
                              alignment: _isOnline
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Today's Summary ──────────────────────────
                  const Text(
                    "Today's Summary",
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Deliveries',
                          value: '8',
                          icon: Icons.local_shipping_rounded,
                          color: Color(0xFF3B1F52),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Earnings',
                          value: '₱ 640',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Color(0xFF2ECC71),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Distance',
                          value: '34 km',
                          icon: Icons.route_rounded,
                          color: Color(0xFFE8873A),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Active Delivery ──────────────────────────
                  const Text(
                    'Active Delivery',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeliveryDetailScreen(),
                      ),
                    ),
                    child: _ActiveDeliveryCard(),
                  ),

                  const SizedBox(height: 24),

                  // ── Recent Deliveries ────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Deliveries',
                        style: TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            color: Color(0xFF7B2FBE),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._recentDeliveries.map(
                    (d) => DeliveryListTile(delivery: d),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Delivery Card
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveDeliveryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8873A).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '#VD-00125',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'On the way',
                  style: TextStyle(
                    color: Color(0xFFE8873A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _AddressRow(
            icon: Icons.radio_button_checked,
            iconColor: const Color(0xFF2ECC71),
            label: 'Pickup',
            value: 'Vendo Warehouse, Quezon City',
          ),
          _DashedDivider(),
          _AddressRow(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFE53935),
            label: 'Drop-off',
            value: '88 Del Monte Ave., Brgy. Manresa, QC',
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),

          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEE6F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF7B2FBE),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedro Bautista',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '+63 912 345 6789',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B3D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.call_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE6F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF2D1B3D),
                  size: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D1B3D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              child: const Text(
                'Confirm Delivered',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
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

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 1),
            color: const Color(0xFFDDDDDD),
          ),
        ),
      ),
    );
  }
}
