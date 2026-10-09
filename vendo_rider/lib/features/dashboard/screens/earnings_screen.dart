import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as home_screen.dart and deliveries_screen.dart
//  • Prune   → dark header, main text
//  • Brique  → small accent (section bars)
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
}

const double _radius = 16;

/// 3840 → '₱ 3,840'
String _peso(int amount) {
  final withCommas = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₱ $withCommas';
}

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  // Placeholder numbers (connect these to your API later)
  static const _monthTotal = 3840;
  static const _monthTrips = 48;

  static const _today = [
    _EarningsEntry(
      id: '#VD-00125',
      customer: 'Pedro Bautista',
      amount: 85,
      time: '11:30 AM',
    ),
    _EarningsEntry(
      id: '#VD-00124',
      customer: 'Maria Santos',
      amount: 80,
      time: '10:42 AM',
    ),
    _EarningsEntry(
      id: '#VD-00123',
      customer: 'Jose Reyes',
      amount: 95,
      time: '9:15 AM',
    ),
    _EarningsEntry(
      id: '#VD-00122',
      customer: 'Ana Cruz',
      amount: 70,
      time: '8:05 AM',
    ),
  ];

  static const _yesterday = [
    _EarningsEntry(
      id: '#VD-00119',
      customer: 'Liza Gomez',
      amount: 90,
      time: '5:00 PM',
    ),
    _EarningsEntry(
      id: '#VD-00118',
      customer: 'Ben Torres',
      amount: 75,
      time: '2:30 PM',
    ),
  ];

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
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SectionTitle('Summary'),
                    SizedBox(height: 12),
                    _PeriodCard(),
                    SizedBox(height: 28),
                    _SectionTitle('Earnings History'),
                    SizedBox(height: 14),
                    _EarningsGroup(day: 'Today', items: _today),
                    _EarningsGroup(day: 'Yesterday', items: _yesterday),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dark header: title + monthly total ───────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final average = (_monthTotal / _monthTrips).round();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
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
            'My Earnings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Income from your completed deliveries',
            style: TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          // Glass-style card (same look as the cards on Home and Deliveries)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Earnings · This month',
                            style: TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _peso(_monthTotal),
                            style: const TextStyle(
                              color: _C.lin,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0x26DBC583),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: _C.lin,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x26FFFFFF),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeaderStat(value: '$_monthTrips', label: 'Trips done'),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0x26FFFFFF),
                    ),
                    _HeaderStat(value: _peso(average), label: 'Avg. per trip'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today / This Week / This Month in one card
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodCard extends StatelessWidget {
  const _PeriodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const _PeriodCell(label: 'Today', value: '₱ 640', trips: '8 trips'),
          Container(width: 1, height: 44, color: _C.border),
          const _PeriodCell(
            label: 'This Week',
            value: '₱ 2,240',
            trips: '28 trips',
          ),
          Container(width: 1, height: 44, color: _C.border),
          const _PeriodCell(
            label: 'This Month',
            value: '₱ 3,840',
            trips: '48 trips',
          ),
        ],
      ),
    );
  }
}

class _PeriodCell extends StatelessWidget {
  final String label, value, trips;

  const _PeriodCell({
    required this.label,
    required this.value,
    required this.trips,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: _C.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: _C.prune,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              trips,
              style: const TextStyle(
                color: _C.raisin,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History: one card per day, one row per trip
// ─────────────────────────────────────────────────────────────────────────────
class _EarningsEntry {
  final String id, customer, time;
  final int amount;

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
    final total = items.fold<int>(0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day name, trip count, and the day's total
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: day,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        TextSpan(
                          text: '  ·  ${items.length} trips',
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _peso(total),
                  style: const TextStyle(
                    color: _C.prune,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _EntryRow(entry: items[i]),
                  if (i != items.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 68,
                      color: _C.border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final _EarningsEntry entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _C.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _C.raisin,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.id,
                  style: const TextStyle(color: _C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ ${_peso(entry.amount)}',
                style: const TextStyle(
                  color: _C.prune,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.time,
                style: const TextStyle(color: _C.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
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
}

class _HeaderStat extends StatelessWidget {
  final String value, label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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