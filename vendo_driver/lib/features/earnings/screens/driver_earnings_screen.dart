import 'package:flutter/material.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

/// The driver's accrued per-stop shipping credits, read from
/// `GET /api/v1/transport-drivers/earnings` on the web ledger.
class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return RefreshIndicator(
      color: VColors.brique,
      onRefresh: store.refreshEarnings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const DriverHeader(
            eyebrow: 'Accrued credits',
            title: 'Earnings',
            subtitle: 'Per-stop shipping shares from completed deliveries.',
          ),
          Padding(
            padding: vPageInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (store.earningsError != null)
                  NoticeCard(
                    tone: NoticeTone.error,
                    icon: Icons.cloud_off_rounded,
                    title: store.earningsSessionExpired
                        ? 'Session expired'
                        : 'Earnings not loaded',
                    message: store.earningsError!,
                    action: TextButton(
                      onPressed: store.earningsSessionExpired
                          ? () => _signInAgain(context)
                          : store.refreshEarnings,
                      child: Text(
                        store.earningsSessionExpired ? 'Sign in' : 'Retry',
                      ),
                    ),
                  )
                else if (store.earnings == null)
                  const _LoadingCard()
                else
                  _SummaryCard(
                    earnings: store.earnings!,
                    refreshing: store.earningsLoading,
                  ),
                const SizedBox(height: 20),
                const SectionTitle('Credits'),
                const SizedBox(height: 10),
                if (store.earnings == null)
                  const EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'Earnings not loaded yet',
                    message:
                        'Pull down to load the credits Vendo has recorded for '
                        'your completed deliveries.',
                  )
                else if (store.earnings!.rows.isEmpty)
                  const EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No accrued credits',
                    message:
                        'When a delivery you moved is completed and its '
                        'shipping share is credited, it appears here.',
                  )
                else
                  VCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < store.earnings!.rows.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                          _EarningRow(earning: store.earnings!.rows[i]),
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
                SizedBox(height: 8 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The stored token was rejected, so the session is dropped before the
  /// sign-in screen opens instead of leaving a screen that cannot load data.
  Future<void> _signInAgain(BuildContext context) async {
    await DriverApi.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const VCard(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VColors.brique,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading the credits Vendo recorded for you…',
              style: TextStyle(color: VColors.muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.earnings,
    required this.refreshing,
  });

  final DriverEarnings earnings;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final count = earnings.hubCredits;
    return VCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Accrued earnings',
                style: TextStyle(
                  color: VColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (refreshing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VColors.brique,
                  ),
                )
              else
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
                    'ACCRUED',
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
            formatPeso(earnings.accruedTotal),
            style: const TextStyle(
              color: VColors.prune,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count completed ${count == 1 ? 'credit' : 'credits'} · accrued '
            'from completed deliveries',
            style: const TextStyle(color: VColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text(
            'These are accrued per-stop credits, not a payout or a salary. '
            'The logistics company pays driver pay outside Vendo.',
            style: TextStyle(
              color: VColors.muted,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.earning});

  final DriverEarning earning;

  @override
  Widget build(BuildContext context) {
    final order = earning.orderNumber.isEmpty ? 'Order' : earning.orderNumber;
    final hub = earning.hub.isEmpty ? 'Route hub' : earning.hub;
    final date = earning.earnedAt == null
        ? ''
        : '${shortDateLabel(earning.earnedAt!)} · ';

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
              Icons.hub_outlined,
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
                  order,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date$hub · Hub ${earning.routePosition}',
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(earning.amount),
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
