import 'package:flutter/material.dart';
import 'package:vendo_rider/core/notifications/rider_notification_center.dart';

/// The in-app banner that slides in at the top of the Rider dashboard when a
/// new notification arrives (a parcel assigned, an assignment released, ...).
class RiderNoticeBanner extends StatelessWidget {
  const RiderNoticeBanner({
    super.key,
    required this.notice,
    required this.onTap,
    required this.onDismiss,
  });

  final RiderNotice? notice;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  static const _prune = Color(0xFF412143);
  static const _muted = Color(0xFF8C8290);
  static const _brique = Color(0xFFBF5E40);
  static const _soft = Color(0xFFF4EDF5);

  @override
  Widget build(BuildContext context) {
    final current = notice;
    if (current == null) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      key: ValueKey(current.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, -22 * (1 - t)), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: const Color(0x33412143),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDE5EE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: _prune,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _prune,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (current.message.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            current.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF544956),
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        const Text(
                          'Tap to open notifications',
                          style: TextStyle(
                            color: _brique,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: _muted,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Dismiss notification',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
