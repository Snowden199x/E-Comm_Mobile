import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/orders/screens/order_detail_screen.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';
import 'package:vendo_buyer/features/support/screens/help_faq_screen.dart';

/// The Buyer's own strikes and suspension state from `GET /account-standing` —
/// the same approved reports the web Account standing page lists.
class AccountStandingScreen extends StatefulWidget {
  const AccountStandingScreen({super.key});

  @override
  State<AccountStandingScreen> createState() => _AccountStandingScreenState();
}

class _AccountStandingScreenState extends State<AccountStandingScreen> {
  ApiStanding? _standing;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final standing = await BuyerApi.instance.standing();
      if (!mounted) return;
      setState(() {
        _standing = standing;
        _loading = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach Vendo. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final standing = _standing;
    return ProfileScaffold(
      title: 'Account Standing',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your standing',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: ProfileColors.header,
              onRefresh: _load,
              child: _content(standing!),
            ),
    );
  }

  Widget _content(ApiStanding standing) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'When Admin approves a report about you, it counts as one strike.',
          style: TextStyle(
            color: ProfileColors.muted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (standing.suspended) ...[
          _suspendedCard(standing),
          const SizedBox(height: 12),
        ],
        _HeadedCard(
          title: 'Your strikes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${standing.strikes}',
                style: TextStyle(
                  color: standing.strikes > 0
                      ? ProfileColors.danger
                      : ProfileColors.green,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _strikeMessage(standing),
                style: const TextStyle(
                  color: ProfileColors.ink,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (standing.ladder.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final step in standing.ladder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      step.summary,
                      style: const TextStyle(
                        color: ProfileColors.muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HeadedCard(
          title: 'Approved reports',
          child: standing.reports.isEmpty
              ? const Text(
                  'No approved reports. Nothing to fix.',
                  style: TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < standing.reports.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: ProfileColors.border),
                      _reportRow(standing.reports[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  String _strikeMessage(ApiStanding standing) {
    if (standing.strikes == 0) {
      return 'You have no strikes. Keep following Vendo policies.';
    }
    if (standing.untilNext != null) {
      final left = standing.untilNext!;
      return '$left more ${left == 1 ? 'strike' : 'strikes'} until your next suspension.';
    }
    return 'You are at the highest step.';
  }

  Widget _reportRow(ApiStandingReport report) {
    final date = report.approvedOn.isNotEmpty
        ? report.approvedOn
        : report.reportedOn;
    return InkWell(
      onTap: () => _showReport(report),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                report.type,
                style: const TextStyle(
                  color: ProfileColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (date.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                date,
                style: const TextStyle(
                  color: ProfileColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ProfileColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _suspendedCard(ApiStanding standing) {
    final notes = standing.suspensionNotes ?? '';
    final until = standing.suspendedUntilLabel != null
        ? 'It ends on ${standing.suspendedUntilLabel}.'
        : 'It has no end date.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF1F3),
        borderRadius: BorderRadius.circular(profileRadius),
        border: Border.all(color: const Color(0xFFE9C7CE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gpp_bad_outlined, size: 18, color: Color(0xFFA32B43)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your account is suspended',
                  style: TextStyle(
                    color: Color(0xFFA32B43),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes.isEmpty ? until : '$until $notes',
            style: const TextStyle(
              color: Color(0xFF7A2A3C),
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
            ),
            child: const Text(
              'Think this is a mistake? Contact support.',
              style: TextStyle(
                color: Color(0xFFA32B43),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReport(ApiStandingReport report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ProfileColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ProfileColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Report details',
                style: TextStyle(
                  color: ProfileColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _HeadedCard(
                title: report.type,
                child: Column(
                  children: [
                    _detailRow('Reported by', report.reporter),
                    _detailRow(
                      'Reported on',
                      report.reportedOn.isEmpty ? '—' : report.reportedOn,
                    ),
                    _detailRow(
                      'Approved on',
                      report.approvedOn.isEmpty ? '—' : report.approvedOn,
                    ),
                    if (report.orderId != null)
                      _detailRow('Order', report.orderLabel),
                    _detailRow(
                      'Effect',
                      '1 strike',
                      valueColor: ProfileColors.danger,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _HeadedCard(
                title: "Admin's note",
                child: Text(
                  report.note?.trim().isNotEmpty == true
                      ? report.note!.trim()
                      : 'Admin did not leave a note.',
                  style: const TextStyle(
                    color: ProfileColors.ink,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              if (report.orderId != null) ...[
                const SizedBox(height: 14),
                ProfilePrimaryButton(
                  label: 'View order',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailScreen(orderId: report.orderId!),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
                    );
                  },
                  child: const Text(
                    'Think this is a mistake? Contact support',
                    style: TextStyle(
                      color: ProfileColors.purple,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 106,
            child: Text(
              label,
              style: const TextStyle(
                color: ProfileColors.muted,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? ProfileColors.ink,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card with the light-lavender heading strip the web page uses.
class _HeadedCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _HeadedCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ProfileColors.white,
        borderRadius: BorderRadius.circular(profileRadius),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: ProfileColors.soft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: const TextStyle(
                color: ProfileColors.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
