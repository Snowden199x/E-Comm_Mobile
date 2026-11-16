import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/orders/screens/order_detail_screen.dart';
import 'package:vendo_buyer/features/orders/screens/orders_screen.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Complaints the Buyer filed, from `GET /complaints` — the same cases and
/// Open / In review / Resolved counts the web Complaints page shows.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  ApiComplaintsPage? _page;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final current = _page;
      final page = await BuyerApi.instance.complaints(
        page: more && current != null ? current.page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        _page = more && current != null ? current.append(page) : page;
        _loading = false;
        _loadingMore = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!more) _error = e.message;
      });
      if (more) _showLoadMoreError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!more) {
          _error =
              'Could not reach Vendo. Check your connection and try again.';
        }
      });
      if (more) {
        _showLoadMoreError('Could not reach Vendo. Check your connection.');
      }
    }
  }

  void _showLoadMoreError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return ProfileScaffold(
      title: 'Complaints',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your complaints',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: ProfileColors.header,
              onRefresh: _load,
              child: _content(page!),
            ),
    );
  }

  Widget _content(ApiComplaintsPage page) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'Reports you sent to Vendo about an order, a shop or a delivery. Admin reviews each case and replies in the case messages.',
          style: TextStyle(
            color: ProfileColors.muted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ProfileColors.header,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _openOrders,
            icon: const Icon(Icons.receipt_long_outlined, size: 17),
            label: const Text(
              'Go to my orders',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CountTile(
                label: 'Open',
                total: page.open,
                tint: const Color(0xFFFEF3C7),
                ink: const Color(0xFFB45309),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CountTile(
                label: 'In review',
                total: page.inReview,
                tint: const Color(0xFFDBEAFE),
                ink: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CountTile(
                label: 'Resolved',
                total: page.resolved,
                tint: const Color(0xFFDCFCE7),
                ink: const Color(0xFF15803D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (page.items.isEmpty)
          _empty()
        else
          for (int i = 0; i < page.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _complaintCard(page.items[i]),
          ],
        if (page.hasMore) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _loadingMore ? null : () => _load(more: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: ProfileColors.header,
                side: const BorderSide(color: ProfileColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ProfileColors.header,
                      ),
                    )
                  : const Text(
                      'Load more',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      decoration: BoxDecoration(
        color: ProfileColors.white,
        borderRadius: BorderRadius.circular(profileRadius),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: ProfileColors.soft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: ProfileColors.purple,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No complaints yet',
            style: TextStyle(
              color: ProfileColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You can report a problem from an order or from a chat with a Seller. Your case and its replies will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ProfileColors.muted,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 170,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ProfileColors.header,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _openOrders,
              child: const Text(
                'View orders',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _complaintCard(ApiComplaint complaint) {
    final tone = _statusTone(complaint.status);
    final meta = <String>[
      if ((complaint.filedAtLabel ?? '').isNotEmpty)
        'Filed ${complaint.filedAtLabel}',
      if ((complaint.respondentName ?? '').isNotEmpty)
        'About ${complaint.respondentName}',
      if (complaint.attachments > 0)
        '${complaint.attachments} ${complaint.attachments == 1 ? 'attachment' : 'attachments'}',
    ];

    return ProfileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _badge(complaint.type, ProfileColors.soft, ProfileColors.header),
              _badge(complaint.statusLabel, tone.$1, tone.$2),
              if (complaint.isAccountReport)
                const Text(
                  'Account report',
                  style: TextStyle(color: ProfileColors.muted, fontSize: 10.5),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            complaint.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ProfileColors.ink,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta.join('  •  '),
              style: const TextStyle(
                color: ProfileColors.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
          if ((complaint.decision ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5EE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC9E5D3)),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF2E6B46),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Admin decision: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: complaint.decision ?? ''),
                  ],
                ),
              ),
            ),
          ],
          if (complaint.orderId != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderDetailScreen(orderId: complaint.orderId!),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ProfileColors.purple,
                  side: const BorderSide(color: ProfileColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 15),
                label: Text(
                  complaint.orderLabel.isEmpty
                      ? 'View order'
                      : 'Order ${complaint.orderLabel}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color background, Color ink) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ink,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, Color) _statusTone(String status) => switch (status) {
    'open' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'in_review' => (const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
    'resolved' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    _ => (const Color(0xFFF1E8F2), const Color(0xFF52245B)),
  };
}

class _CountTile extends StatelessWidget {
  final String label;
  final int total;
  final Color tint;
  final Color ink;

  const _CountTile({
    required this.label,
    required this.total,
    required this.tint,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: ProfileColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Text(
              '$total',
              style: TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ProfileColors.muted,
              fontSize: 9.5,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            total == 1 ? '1 complaint' : '$total complaints',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ProfileColors.ink, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
