import 'package:flutter/material.dart';

/// Thin notice shown while the Rider app is working from saved data.
///
/// It always says how old the saved work is and how many offline updates are
/// still waiting, so a Rider never mistakes a cached list for live dispatch.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.savedAt,
    this.pending = 0,
    this.onRetry,
  });

  final DateTime? savedAt;
  final int pending;
  final VoidCallback? onRetry;

  static String ageLabel(DateTime? at) {
    if (at == null) return 'Saved on this device';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Saved just now';
    if (diff.inMinutes < 60) return 'Saved ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Saved ${diff.inHours} h ago';
    return 'Saved ${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final pendingLabel = pending == 0
        ? 'Scans you take now upload when the signal returns.'
        : '$pending offline update${pending == 1 ? '' : 's'} waiting to upload.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1DC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3D09A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: Color(0xFF8A6D1A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline — showing saved parcels',
                  style: TextStyle(
                    color: Color(0xFF412143),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ageLabel(savedAt)}. $pendingLabel',
                  style: const TextStyle(
                    color: Color(0xFF6B5A2E),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
