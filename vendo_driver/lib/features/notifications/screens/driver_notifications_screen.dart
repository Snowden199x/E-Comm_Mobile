import 'package:flutter/material.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

/// Notifications the web addressed to the driver's account: a trip assigned,
/// a manifest handoff, an arrival record or a company update.
class DriverNotificationsScreen extends StatelessWidget {
  const DriverNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return Scaffold(
      backgroundColor: VColors.background,
      body: RefreshIndicator(
        color: VColors.brique,
        onRefresh: store.refreshNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            DriverHeader(
              eyebrow: store.unreadNotifications == 0
                  ? 'All caught up'
                  : '${store.unreadNotifications} unread',
              title: 'Notifications',
              subtitle: 'Trip assignments and updates from your logistics '
                  'company.',
              onBack: () => Navigator.of(context).maybePop(),
              trailing: store.unreadNotifications == 0
                  ? null
                  : DriverCircleButton(
                      icon: Icons.done_all_rounded,
                      tooltip: 'Mark all as read',
                      onTap: store.markAllNotificationsRead,
                    ),
            ),
            Padding(
              padding: vPageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (store.notificationsError != null)
                    NoticeCard(
                      tone: NoticeTone.error,
                      icon: Icons.cloud_off_rounded,
                      title: store.notificationsSessionExpired
                          ? 'Session expired'
                          : 'Notifications not loaded',
                      message: store.notificationsError!,
                      action: TextButton(
                        onPressed: store.notificationsSessionExpired
                            ? () => _signInAgain(context)
                            : store.refreshNotifications,
                        child: Text(
                          store.notificationsSessionExpired
                              ? 'Sign in'
                              : 'Retry',
                        ),
                      ),
                    )
                  else if (store.notifications.isEmpty &&
                      store.notificationsLoading)
                    const VCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 26,
                      ),
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
                              'Loading your notifications…',
                              style: TextStyle(
                                color: VColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (store.notifications.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Nothing new',
                      message:
                          'When the hub assigns you a trip or your logistics '
                          'company posts an update, it shows up here.',
                    )
                  else
                    for (final notification in store.notifications) ...[
                      _NotificationCard(
                        notification: notification,
                        onTap: () => store.markNotificationRead(
                          notification.id,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  SizedBox(height: 8 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInAgain(BuildContext context) async {
    await DriverApi.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final DriverNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    return VCard(
      onTap: unread ? onTap : null,
      color: unread ? VColors.raisinSoft.withValues(alpha: 0.35) : Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: unread ? VColors.prune : VColors.raisinSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _iconFor(notification.type),
              color: unread ? Colors.white : VColors.raisin,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title.isEmpty
                            ? 'Vendo update'
                            : notification.title,
                        style: TextStyle(
                          color: VColors.ink,
                          fontSize: 13,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 8, top: 2),
                        decoration: const BoxDecoration(
                          color: VColors.brique,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notification.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: VColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  notification.createdAt == null
                      ? ''
                      : dateTimeLabel(notification.createdAt!),
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'transport_manifest_assigned' => Icons.assignment_outlined,
      'logistics_trip_arrived' => Icons.flag_outlined,
      'logistics_handoff' => Icons.swap_horiz_rounded,
      'shipment_update' || 'tracking_update' => Icons.local_shipping_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }
}
