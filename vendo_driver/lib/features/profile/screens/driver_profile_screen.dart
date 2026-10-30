import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Sign out?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'You will need your approved account to sign in again. Demo data on '
          'this device is not affected.',
          style: TextStyle(color: VColors.muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = DriverStore.instance.profile;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DriverHeader(
          eyebrow: 'Transport driver',
          title: profile.name,
          subtitle: '${profile.company} · ${profile.hub}',
          trailing: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Padding(
          padding: vPageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Driver license',
                      value: profile.licenseNumber,
                      trailing: StatusPill(
                        label: profile.licenseValid ? 'Valid' : 'Expired',
                        foreground: profile.licenseValid
                            ? VColors.green
                            : VColors.red,
                        background: profile.licenseValid
                            ? VColors.greenSoft
                            : VColors.redSoft,
                        icon: profile.licenseValid
                            ? Icons.verified_rounded
                            : Icons.error_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InfoRow(
                      icon: Icons.event_outlined,
                      label: 'License expiry',
                      value: shortDateLabel(profile.licenseExpiry),
                    ),
                    const SizedBox(height: 14),
                    InfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: profile.email,
                    ),
                    const SizedBox(height: 14),
                    InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Mobile number',
                      value: profile.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('Assignment'),
              const SizedBox(height: 10),
              VCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Province Hub',
                      value: profile.hub,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          profile.hubArea,
                          style: const TextStyle(
                            color: VColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InfoRow(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: profile.company,
                    ),
                    const SizedBox(height: 14),
                    InfoRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Assigned vehicle',
                      value: profile.vehicle,
                      trailing: StatusPill(
                        label: profile.plate,
                        foreground: VColors.raisin,
                        background: VColors.raisinSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('Coming later'),
              const SizedBox(height: 10),
              VCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: const [
                    _LaterRow(
                      icon: Icons.qr_code_scanner_outlined,
                      title: 'Container scanner',
                      message: 'Open a container label and its manifest.',
                    ),
                    _LaterRow(
                      icon: Icons.fact_check_outlined,
                      title: 'Per-parcel scan status',
                      message: 'See which origin and destination scans are done.',
                      showDivider: true,
                    ),
                    _LaterRow(
                      icon: Icons.report_problem_outlined,
                      title: 'Incident and discrepancy report',
                      message: 'Report a breakdown or a missing parcel.',
                      showDivider: true,
                    ),
                    _LaterRow(
                      icon: Icons.history_rounded,
                      title: 'Trip history',
                      message: 'Completed and cancelled trips with reasons.',
                      showDivider: true,
                    ),
                    _LaterRow(
                      icon: Icons.payments_outlined,
                      title: 'Salary and payslips',
                      message: 'Pay records from the logistics company.',
                      showDivider: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Vendo Driver · Build 1.0.0 · Demo build, no server connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VColors.muted, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LaterRow extends StatelessWidget {
  const _LaterRow({
    required this.icon,
    required this.title,
    required this.message,
    this.showDivider = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: VColors.muted, size: 17),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: VColors.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: VColors.muted,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LaterPill(),
            ],
          ),
        ),
      ],
    );
  }
}
