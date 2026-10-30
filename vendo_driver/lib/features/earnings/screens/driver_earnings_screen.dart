import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;
    final credits = store.legacyCredits;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const DriverHeader(
          eyebrow: 'Legacy credits',
          title: 'Earnings',
          subtitle: 'Per-stop credits from orders created before the new rule.',
        ),
        Padding(
          padding: vPageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Old-order earnings',
                          style: TextStyle(
                            color: VColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: VColors.raisinSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'OLD ORDERS ONLY',
                            style: TextStyle(
                              color: VColors.raisin,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatPeso(store.legacyTotal),
                      style: const TextStyle(
                        color: VColors.prune,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${credits.length} old orders · ${store.legacyStops} completed stops',
                      style: const TextStyle(
                        color: VColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'These are accrued per-stop credits, not a payout or a '
                      'salary. The logistics company pays driver pay outside '
                      'Vendo.',
                      style: TextStyle(
                        color: VColors.muted,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const NoticeCard(
                icon: Icons.info_outline_rounded,
                title: 'Why only old orders?',
                message:
                    'New orders no longer create driver credits. Only '
                    'completed stops from legacy orders are listed here.',
              ),
              const SizedBox(height: 20),
              const SectionTitle('Credits'),
              const SizedBox(height: 10),
              if (credits.isEmpty)
                const EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No old-order credits',
                  message:
                      'When a legacy order completes a stop, its credit '
                      'appears here.',
                )
              else
                VCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < credits.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                        _CreditRow(credit: credits[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: VColors.muted,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Salary, payslips, payroll questions and pay records '
                      'are planned for a later version. Ask your logistics '
                      'company about driver pay.',
                      style: TextStyle(
                        color: VColors.muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const LaterPill(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final LegacyCredit credit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: VColors.raisinSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: VColors.raisin,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credit.trip,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shortDateLabel(credit.date)} · ${credit.stops} stops × ₱10',
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(credit.amount),
            style: const TextStyle(
              color: VColors.prune,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
