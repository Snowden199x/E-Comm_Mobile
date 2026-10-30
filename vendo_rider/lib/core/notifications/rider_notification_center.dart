import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

/// One notification addressed to the signed-in Rider.
class RiderNotice {
  const RiderNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool read;

  static RiderNotice? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = int.tryParse(raw['id']?.toString() ?? '');
    if (id == null) return null;
    final title = raw['title']?.toString().trim() ?? '';
    return RiderNotice(
      id: id,
      type: raw['type']?.toString() ?? 'rider_update',
      title: title.isEmpty ? 'Vendo update' : title,
      message: raw['message']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? ''),
      read: raw['read_at'] != null,
    );
  }
}

/// Keeps the Rider app's unread badge and top banner in sync with the server
/// while the app is open.
///
/// The Notifications tab still loads the full list itself; this only watches
/// for arrivals. The first poll only primes the watermark, so old unread items
/// do not pop up as if they just happened - unless they are genuinely recent.
class RiderNotificationCenter extends ChangeNotifier {
  RiderNotificationCenter._();

  static final RiderNotificationCenter instance = RiderNotificationCenter._();

  /// How often the open app checks for new notifications.
  static const pollInterval = Duration(seconds: 25);

  /// How old an unread notification may be and still raise a banner when the
  /// rider opens the app. Older items stay in the Notifications tab.
  static const bannerWindow = Duration(minutes: 10);

  Timer? _timer;
  bool _running = false;
  bool _polling = false;
  int _watermark = 0;
  int _unreadCount = 0;
  RiderNotice? _banner;

  int get unreadCount => _unreadCount;
  RiderNotice? get banner => _banner;

  void start() {
    if (_running) return;
    _running = true;
    unawaited(poll());
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _banner = null;
    // A different account may sign in on this device next; start it clean.
    _watermark = 0;
    _unreadCount = 0;
  }

  void dismissBanner() {
    if (_banner == null) return;
    _banner = null;
    notifyListeners();
  }

  /// Called by the Notifications tab after one item is read on the server.
  void noteRead(int notificationId) {
    final clearsBanner = _banner?.id == notificationId;
    if (clearsBanner) _banner = null;
    final next = (_unreadCount - 1).clamp(0, 999999);
    if (clearsBanner || next != _unreadCount) {
      _unreadCount = next;
      notifyListeners();
    }
  }

  /// Called by the Notifications tab after "mark all read" succeeds.
  void noteAllRead() {
    if (_unreadCount == 0 && _banner == null) return;
    _unreadCount = 0;
    _banner = null;
    notifyListeners();
  }

  /// Adopts the unread count the Notifications tab just loaded.
  void adoptUnread(int count) {
    final next = count.clamp(0, 999999);
    if (next == _unreadCount) return;
    _unreadCount = next;
    notifyListeners();
  }

  Future<void> poll() async {
    if (_polling) return;
    _polling = true;
    try {
      if (!await RiderApi.instance.hasToken()) return;
      final data = await RiderApi.instance.riderNotifications(
        since: _watermark > 0 ? _watermark : null,
      );
      final rows = (data['data'] as List<dynamic>? ?? const [])
          .map(RiderNotice.tryParse)
          .whereType<RiderNotice>()
          .toList();
      final latest = int.tryParse(data['latest_id']?.toString() ?? '') ?? 0;
      final unread =
          int.tryParse(data['unread_count']?.toString() ?? '') ?? _unreadCount;

      var bannerChanged = false;
      final firstPoll = _watermark == 0;
      final fresh = rows
          .where((row) => !row.read && (firstPoll ? _isRecent(row) : row.id > _watermark))
          .toList();
      if (fresh.isNotEmpty && _banner?.id != fresh.first.id) {
        _banner = fresh.first;
        bannerChanged = true;
      }
      if (latest > _watermark) _watermark = latest;

      final unreadChanged = unread != _unreadCount;
      _unreadCount = unread;
      if (unreadChanged || bannerChanged) notifyListeners();
    } catch (_) {
      // Offline, signed out, or the server is down: keep the last badge and
      // retry on the next tick instead of interrupting the rider.
    } finally {
      _polling = false;
    }
  }

  bool _isRecent(RiderNotice notice) {
    final createdAt = notice.createdAt;
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt) <= bannerWindow;
  }
}
