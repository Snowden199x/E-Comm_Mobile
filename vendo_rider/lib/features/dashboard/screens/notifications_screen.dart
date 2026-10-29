import 'package:flutter/material.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  static const _purple = Color(0xFF412143);
  static const _muted = Color(0xFF8C8290);
  static const _background = Color(0xFFFAF7F5);

  List<Map<String, dynamic>> _items = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    refreshNotifications();
  }

  Future<void> refreshNotifications() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await RiderApi.instance.riderNotifications();
      final rows = (result['data'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) setState(() {
        _items = rows;
        _unreadCount = int.tryParse(result['unread_count']?.toString() ?? '') ?? 0;
      });
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load notifications. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    try {
      await RiderApi.instance.markRiderNotificationRead(int.parse(item['id'].toString()));
      if (!mounted) return;
      setState(() {
        item['read_at'] = DateTime.now().toIso8601String();
        _unreadCount = (_unreadCount - 1).clamp(0, 999999).toInt();
      });
    } on RiderApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this notification.')));
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0 || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      await RiderApi.instance.markAllRiderNotificationsRead();
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
        for (final item in _items) {
          item['read_at'] ??= DateTime.now().toIso8601String();
        }
      });
    } on RiderApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _purple,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: Text(_markingAll ? 'Saving…' : 'Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshNotifications,
        color: _purple,
        child: _loading && _items.isEmpty
            ? ListView(children: [const SizedBox(height: 240), Center(child: CircularProgressIndicator())])
            : _error != null && _items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        const Icon(Icons.cloud_off_outlined, color: _muted, size: 36),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
                        TextButton(onPressed: refreshNotifications, child: const Text('Retry')),
                      ]),
                    )),
                  ])
                : _items.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 105),
                        Icon(Icons.notifications_none_rounded, color: _muted, size: 46),
                        SizedBox(height: 12),
                        Center(child: Text('You’re all caught up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _purple))),
                        SizedBox(height: 6),
                        Center(child: Text('Parcel and delivery updates will appear here.', style: TextStyle(color: _muted))),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final unread = item['read_at'] == null;
                          return Material(
                            color: unread ? Colors.white : const Color(0xFFF4F0F3),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _markRead(item),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(color: const Color(0xFFF4EDF5), borderRadius: BorderRadius.circular(13)),
                                    child: const Icon(Icons.notifications_active_outlined, color: _purple),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(item['title']?.toString() ?? 'Vendo update', style: const TextStyle(color: _purple, fontWeight: FontWeight.w700))),
                                      if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFBF5E40), shape: BoxShape.circle)),
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(item['message']?.toString() ?? '', style: const TextStyle(color: Color(0xFF544956), height: 1.35)),
                                    const SizedBox(height: 7),
                                    Text(item['time_ago']?.toString() ?? '', style: const TextStyle(color: _muted, fontSize: 12)),
                                  ])),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
