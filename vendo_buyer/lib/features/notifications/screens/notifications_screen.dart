import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/offline_banner.dart';

/// Buyer notifications from `GET /api/v1/buyer/notifications`, scoped to the signed-in Buyer.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _purple = Color(0xFF3B1F52);
  static const _purpleMid = Color(0xFF7B2FBE);
  static const _bg = Color(0xFFF4F1F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF888888);
  static const _border = Color(0xFFECE6EA);

  List<ApiNotification> _items = const [];
  bool _loading = true;
  String? _error;

  /// Set when the list came from the device instead of Vendo.
  DateTime? _offlineSince;

  /// True when "mark all read" is queued on the device but not uploaded yet.
  bool _pendingReadAll = false;

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
      final items = await BuyerApi.instance.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _offlineSince = null;
        _loading = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      // Offline: show the notifications saved on this device.
      final cached = await BuyerApi.instance.cachedNotifications();
      if (!mounted) return;
      if (cached == null) {
        setState(() {
          _error = 'Could not reach Vendo and no saved notifications are on this device yet.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _items = cached.items;
        _offlineSince = cached.cachedAt;
        _error = null;
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await BuyerApi.instance.markAllNotificationsRead();
      if (mounted) _load();
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      // No connection: keep it on the device and show the list as read here.
      await BuyerApi.instance.queueMarkAllNotificationsReadOffline();
      if (!mounted) return;
      setState(() => _pendingReadAll = true);
      _toast('Saved on this device — it uploads when you are back online.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final unread = _pendingReadAll
        ? 0
        : _items.where((item) => !item.read).length;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
        bottom: _offlineSince == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(68),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: OfflineBanner(savedAt: _offlineSince, onRetry: _load),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _purpleMid),
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text('No notifications yet.', style: TextStyle(color: _muted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final item = _items[index];
                          final read = item.read || _pendingReadAll;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: read ? Colors.white : const Color(0xFFF6EFFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _ink,
                                        ),
                                      ),
                                    ),
                                    if (!read)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: _purpleMid,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.message,
                                  style: const TextStyle(fontSize: 12, color: _ink, height: 1.4),
                                ),
                                if ((item.timeAgo ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.timeAgo!,
                                    style: const TextStyle(fontSize: 10.5, color: _muted),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
