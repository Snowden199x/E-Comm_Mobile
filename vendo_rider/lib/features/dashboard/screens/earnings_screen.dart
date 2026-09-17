import 'package:flutter/material.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header with total ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B1F52), Color(0xFF2A1440)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Earnings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Earnings',
                                style: TextStyle(
                                  color: Color(0xAAFFFFFF),
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₱ 3,840',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'This month',
                                style: TextStyle(
                                  color: Color(0xAAFFFFFF),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.trending_up_rounded,
                            color: Color(0xFF2ECC71),
                            size: 28,
                          ),
                        ),
                      ],
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
                  // ── Breakdown stats ────────────────────────
                  const Row(
                    children: [
                      Expanded(
                        child: _EarningsStat(
                          label: 'Today',
                          value: '₱ 640',
                          sub: '8 trips',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _EarningsStat(
                          label: 'This Week',
                          value: '₱ 2,240',
                          sub: '28 trips',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _EarningsStat(
                          label: 'This Month',
                          value: '₱ 3,840',
                          sub: '48 trips',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Earnings History',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _EarningsGroup(
                    day: 'Today',
                    items: const [
                      _EarningsEntry(
                        id: '#VD-00125',
                        customer: 'Pedro Bautista',
                        amount: '₱ 85',
                        time: '11:30 AM',
                      ),
                      _EarningsEntry(
                        id: '#VD-00124',
                        customer: 'Maria Santos',
                        amount: '₱ 80',
                        time: '10:42 AM',
                      ),
                      _EarningsEntry(
                        id: '#VD-00123',
                        customer: 'Jose Reyes',
                        amount: '₱ 95',
                        time: '9:15 AM',
                      ),
                      _EarningsEntry(
                        id: '#VD-00122',
                        customer: 'Ana Cruz',
                        amount: '₱ 70',
                        time: '8:05 AM',
                      ),
                    ],
                  ),
                  _EarningsGroup(
                    day: 'Yesterday',
                    items: const [
                      _EarningsEntry(
                        id: '#VD-00119',
                        customer: 'Liza Gomez',
                        amount: '₱ 90',
                        time: '5:00 PM',
                      ),
                      _EarningsEntry(
                        id: '#VD-00118',
                        customer: 'Ben Torres',
                        amount: '₱ 75',
                        time: '2:30 PM',
                      ),
                    ],
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

class _EarningsStat extends StatelessWidget {
  final String label, value, sub;
  const _EarningsStat({
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D1B3D),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EarningsEntry {
  final String id, customer, amount, time;
  const _EarningsEntry({
    required this.id,
    required this.customer,
    required this.amount,
    required this.time,
  });
}

class _EarningsGroup extends StatelessWidget {
  final String day;
  final List<_EarningsEntry> items;
  const _EarningsGroup({required this.day, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            day,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...items.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 4),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF2D1B3D),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.id,
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        e.customer,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      e.amount,
                      style: const TextStyle(
                        color: Color(0xFF2D1B3D),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      e.time,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
