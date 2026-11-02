import 'package:flutter/material.dart';

/// Thin notice shown while the Buyer app is working from saved data.
///
/// It always says how old the saved data is, so a Buyer never mistakes a cached
/// order list or tracking page for live status.
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
        ? 'Updates you make now upload when the signal returns.'
        : '$pending update${pending == 1 ? '' : 's'} waiting to upload.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9C7EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: Color(0xFF7B2FBE),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline — showing saved details',
                  style: TextStyle(
                    color: Color(0xFF3B1F52),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ageLabel(savedAt)}. $pendingLabel',
                  style: const TextStyle(
                    color: Color(0xFF5B4A60),
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
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
