import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/core/notifications/rider_notification_center.dart';
import 'package:vendo_rider/features/dashboard/widgets/offline_banner.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  // Vendo "Warm Courier Kinetic" palette (same as the other rider screens)
  static const _purple = Color(0xFF3C2143);
  static const _purpleDeep = Color(0xFF25102A);
  static const _purpleMid = Color(0xFF33173A);
  static const _purpleLight = Color(0xFF3F1E47);
  static const _muted = Color(0xFF7D747D);
  static const _background = Color(0xFFFAF7F2);
  static const _border = Color(0xFFEDE6DD);

  List<Map<String, dynamic>> _items = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;
  bool _markingAll = false;

  /// Set when the list shown came from the device instead of Vendo.
  DateTime? _offlineSince;

  // Drives the header animation (loops forever, 0.0 → 1.0). Created on first
  // use rather than in initState, so a rebuild that beats initState (or a hot
  // reload that skips it) can never read it uninitialized.
  AnimationController? _bg;
  AnimationController get _bgController => _bg ??= AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void initState() {
    super.initState();
    refreshNotifications();
  }

  @override
  void dispose() {
    _bg?.dispose();
    super.dispose();
  }

  Future<void> refreshNotifications() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await RiderApi.instance.riderNotifications();
      final rows = (result['data'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final unread =
          int.tryParse(result['unread_count']?.toString() ?? '') ?? 0;
      if (mounted) setState(() {
        _items = rows;
        _unreadCount = unread;
        _offlineSince = null;
      });
      RiderNotificationCenter.instance.adoptUnread(unread);
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      // Offline: show the list saved on this device instead of an error page.
      final cached = await RiderApi.instance.cachedNotifications();
      if (!mounted) return;
      if (cached == null) {
        setState(() => _error = 'Could not load notifications. Pull down to retry.');
      } else {
        final rows = (cached.payload['data'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        setState(() {
          _items = rows;
          _unreadCount =
              int.tryParse('${cached.payload['unread_count'] ?? ''}') ?? 0;
          _offlineSince = cached.cachedAt;
          _error = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    final id = int.parse(item['id'].toString());
    try {
      await RiderApi.instance.markRiderNotificationRead(id);
      if (!mounted) return;
      setState(() {
        item['read_at'] = DateTime.now().toIso8601String();
        _unreadCount = (_unreadCount - 1).clamp(0, 999999).toInt();
      });
      RiderNotificationCenter.instance.noteRead(id);
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
      RiderNotificationCenter.instance.noteAllRead();
    } on RiderApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_offlineSince != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: OfflineBanner(
                  savedAt: _offlineSince,
                  onRetry: refreshNotifications,
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Dark header: animated backdrop + back + title + mark all read ────────
  Widget _buildHeader() {
    final topInset = MediaQuery.of(context).padding.top;
    // Same as the old AppBar: a back button only when this screen was pushed.
    final canGoBack = Navigator.of(context).canPop();

    return ClipRRect(
      // Everything animated stays inside this rounded shape
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_purpleDeep, _purpleMid, _purpleLight],
          ),
        ),
        child: Stack(
          children: [
            // Moving background (does not block taps, does not change size)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, _) => CustomPaint(
                      painter: _HeaderBackdropPainter(_bgController.value),
                    ),
                  ),
                ),
              ),
            ),
            // Real content on top
            Padding(
              padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 18),
              child: Row(
                children: [
                  if (canGoBack) ...[
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: Material(
                        color: const Color(0x1AFFFFFF),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.maybePop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x26FFFFFF)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      'Notifications',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 10),
                    _buildNewBadge(),
                  ],
                  const Spacer(),
                  if (_unreadCount > 0) _buildMarkAllButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "• 2 new" pill with a softly pulsing dot
  Widget _buildNewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x4DF43F5E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x66FB7185)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(
            controller: _bgController,
            color: const Color(0xFFFB7185),
            size: 6,
          ),
          const SizedBox(width: 6),
          Text(
            '$_unreadCount new',
            style: const TextStyle(
              color: Color(0xFFFECDD3),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAllButton() {
    return Material(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _markingAll ? null : _markAllRead,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all_rounded, color: Color(0xFFE9D5FF), size: 14),
              const SizedBox(width: 5),
              Text(
                _markingAll ? 'Saving…' : 'Mark all read',
                style: const TextStyle(
                  color: Color(0xFFF3E8FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body: loading / error / empty / list (all keep pull-to-refresh) ──────
  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: refreshNotifications,
      color: _purple,
      child: _loading && _items.isEmpty
          ? ListView(children: [const SizedBox(height: 200), Center(child: CircularProgressIndicator(color: _purple))])
          : _error != null && _items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 90),
                  Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF2EAF5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_off_outlined, color: _muted, size: 30),
                      ),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
                      TextButton(onPressed: refreshNotifications, child: const Text('Retry')),
                    ]),
                  )),
                ])
              : _items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D3C2143),
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: _purple, size: 36),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Center(child: Text('You’re all caught up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _purple))),
                      const SizedBox(height: 6),
                      const Center(child: Text('Parcel and delivery updates will appear here.', style: TextStyle(color: _muted))),
                    ])
                  : _buildFeed(),
    );
  }

  // ── Day groups (Today / Yesterday / Earlier this week / Earlier) ─────────
  static const _groupLabels = ['Today', 'Yesterday', 'Earlier this week', 'Earlier'];

  /// 0 = today, 1 = yesterday, 2 = 2–6 days ago, 3 = a week or more.
  /// Uses the notification's date when the API sends one, otherwise reads
  /// the "10m ago" / "1 day ago" text.
  int _dayGroup(Map<String, dynamic> item) {
    final now = DateTime.now();

    for (final key in const ['created_at', 'date']) {
      final created = DateTime.tryParse(item[key]?.toString() ?? '')?.toLocal();
      if (created != null) {
        final days = DateTime(now.year, now.month, now.day)
            .difference(DateTime(created.year, created.month, created.day))
            .inDays;
        if (days <= 0) return 0;
        if (days == 1) return 1;
        return days < 7 ? 2 : 3;
      }
    }

    final text = (item['time_ago']?.toString() ?? '').toLowerCase();
    if (text.contains('yesterday')) return 1;
    if (text.contains('just now') || text.contains('now')) return 0;
    final match = RegExp(
      r'(\d+)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?|days?|weeks?|months?|years?|mo|s|m|h|d|w|y)\b',
    ).firstMatch(text);
    if (match == null) return 3;
    final n = int.tryParse(match.group(1) ?? '') ?? 0;
    final unit = match.group(2) ?? '';
    if (unit.startsWith('s')) {
      return 0;
    }
    if (unit.startsWith('mi') || unit == 'm') {
      return n <= now.hour * 60 + now.minute ? 0 : 1;
    }
    if (unit.startsWith('h')) {
      return n * 60 <= now.hour * 60 + now.minute ? 0 : 1;
    }
    if (unit.startsWith('d')) {
      if (n <= 0) return 0;
      if (n == 1) return 1;
      return n < 7 ? 2 : 3;
    }
    return 3; // weeks, months, years
  }

  Widget _buildFeed() {
    // Keep the order the API gave us; add a divider whenever the group changes.
    final groups = _items.map(_dayGroup).toList();
    final counts = <int, int>{};
    final unreadCounts = <int, int>{};
    for (var i = 0; i < _items.length; i++) {
      counts[groups[i]] = (counts[groups[i]] ?? 0) + 1;
      if (_items[i]['read_at'] == null) {
        unreadCounts[groups[i]] = (unreadCounts[groups[i]] ?? 0) + 1;
      }
    }

    final rows = <Widget>[];
    int? previous;
    for (var i = 0; i < _items.length; i++) {
      final group = groups[i];
      if (group != previous) {
        rows.add(_buildDayHeader(
          group,
          counts[group] ?? 0,
          unreadCounts[group] ?? 0,
          first: previous == null,
        ));
        previous = group;
      }
      final item = _items[i];
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildItemCard(item, item['read_at'] == null),
      ));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      children: rows,
    );
  }

  Widget _buildDayHeader(int group, int count, int unread, {required bool first}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 2 : 14, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _groupLabels[group],
            style: const TextStyle(
              color: _purple,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (unread > 0)
            Text(
              '$unread new',
              style: const TextStyle(
                color: Color(0xFFA23E18),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  // ── One notification card (icon + colors depend on the kind) ─────────────
  Widget _buildItemCard(Map<String, dynamic> item, bool unread) {
    final timeAgo = item['time_ago']?.toString() ?? '';
    final message = item['message']?.toString() ?? '';
    final kind = _NoteStyle.of(item);

    return Container(
      decoration: BoxDecoration(
        color: unread ? kind.cardBg : const Color(0xFFFCFAF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: unread ? kind.border : const Color(0xFFF0EBE4)),
        boxShadow: unread
            ? const [
                BoxShadow(
                  color: Color(0x0D3C2143),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _markRead(item),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar in the kind's color (softer once read)
                Container(
                  width: 5,
                  color: unread ? kind.fg : kind.fg.withAlpha(90),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: kind.bg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: kind.border),
                          ),
                          child: Icon(
                            kind.icon,
                            color: unread ? kind.fg : kind.fg.withAlpha(170),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          kind.label,
                                          style: TextStyle(
                                            color: kind.fg,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.9,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['title']?.toString() ?? 'Vendo update',
                                          style: TextStyle(
                                            color: _purple,
                                            fontSize: 14,
                                            fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (timeAgo.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: unread ? kind.bg : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        timeAgo,
                                        style: TextStyle(
                                          color: unread ? kind.dark : _muted,
                                          fontSize: 11,
                                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: unread ? const Color(0xFF544956) : _muted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (unread) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kind.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kind.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _PulseDot(
                                        controller: _bgController,
                                        color: kind.fg,
                                        size: 6,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'New • tap to mark as read',
                                        style: TextStyle(
                                          color: kind.dark,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification kinds: each one has its own icon, label and color set.
//
// The kind is guessed from the notification's title first, then its
// type/category/kind field (if the API sends one), then its message.
// Order matters: problems are checked first, so "Delivery failed" is an alert
// and not a delivery assignment.
// ─────────────────────────────────────────────────────────────────────────────
class _NoteStyle {
  final String label;
  final IconData icon;
  final Color fg, dark, bg, border, cardBg;

  const _NoteStyle({
    required this.label,
    required this.icon,
    required this.fg,
    required this.dark,
    required this.bg,
    required this.border,
    this.cardBg = Colors.white,
  });

  static const delivery = _NoteStyle(
    label: 'DELIVERY',
    icon: Icons.local_shipping_outlined,
    fg: Color(0xFFC85A32),
    dark: Color(0xFFA23E18),
    bg: Color(0xFFFFF3EC),
    border: Color(0x33C85A32),
  );

  static const pickup = _NoteStyle(
    label: 'PICKUP',
    icon: Icons.inventory_2_outlined,
    fg: Color(0xFFD97706),
    dark: Color(0xFF92400E),
    bg: Color(0xFFFFF8E7),
    border: Color(0x4DF59E0B),
  );

  static const linehaul = _NoteStyle(
    label: 'LINEHAUL',
    icon: Icons.route_rounded,
    fg: Color(0xFF815488),
    dark: Color(0xFF3C2143),
    bg: Color(0xFFF2EAF5),
    border: Color(0x33815488),
  );

  static const delivered = _NoteStyle(
    label: 'DELIVERED',
    icon: Icons.check_circle_outline_rounded,
    fg: Color(0xFF059669),
    dark: Color(0xFF047857),
    bg: Color(0xFFECFDF5),
    border: Color(0x4D34D399),
  );

  static const alert = _NoteStyle(
    label: 'ALERT',
    icon: Icons.warning_amber_rounded,
    fg: Color(0xFFE11D48),
    dark: Color(0xFF9F1239),
    bg: Color(0xFFFFF1F2),
    border: Color(0x4DFB7185),
    cardBg: Color(0xFFFFF7F8),
  );

  static const earnings = _NoteStyle(
    label: 'EARNINGS',
    icon: Icons.account_balance_wallet_outlined,
    fg: Color(0xFF0E7490),
    dark: Color(0xFF155E75),
    bg: Color(0xFFECFEFF),
    border: Color(0x4D22D3EE),
  );

  static const general = _NoteStyle(
    label: 'UPDATE',
    icon: Icons.notifications_active_outlined,
    fg: Color(0xFF3C2143),
    dark: Color(0xFF3C2143),
    bg: Color(0xFFF2EAF5),
    border: Color(0x143C2143),
  );

  static bool _has(String s, List<String> words) =>
      words.any((w) => s.contains(w));

  static _NoteStyle _fromText(String raw) {
    final s = raw.toLowerCase();
    if (s.trim().isEmpty) return general;
    if (_has(s, [
      'fail', 'cancel', 'closed', 'overdue', 'missed', 'return', 'reject',
      'expire', 'deadline', 'delay', 'unable', 'problem', 'issue', 'alert',
    ])) {
      return alert;
    }
    if (_has(s, ['delivered', 'completed', 'complete', 'success'])) {
      return delivered;
    }
    if (_has(s, [
      'earning', 'payout', 'payment', 'paid', 'cash', 'cod', 'remit', 'wallet',
    ])) {
      return earnings;
    }
    if (_has(s, ['pickup', 'pick up', 'pick-up'])) return pickup;
    if (_has(s, ['linehaul', 'line haul', 'truck', 'transfer'])) {
      return linehaul;
    }
    if (_has(s, ['deliver', 'assign'])) return delivery;
    return general;
  }

  static _NoteStyle of(Map<String, dynamic> item) {
    for (final key in const ['title', 'type', 'category', 'kind', 'message']) {
      final style = _fromText(item[key]?.toString() ?? '');
      if (!identical(style, general)) return style;
    }
    return general;
  }
}

// Small dot that pulses softly (7 whole pulses per 14s loop → seamless)
class _PulseDot extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;

  const _PulseDot({
    required this.controller,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulse = 0.5 + 0.5 * math.sin(controller.value * math.pi * 2 * 7);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withAlpha((120 + pulse * 135).round()),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((pulse * 90).round()),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated header backdrop
//
// `t` loops from 0.0 to 1.0. Every movement uses whole sine cycles or
// wrap-around values, so the loop is seamless (no jump when it restarts).
// Layers: coral/violet aurora glows, a soft "ping" ring, small floating dots,
// and a faint shimmer sweep. Draws only inside the header.
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderBackdropPainter extends CustomPainter {
  final double t;

  _HeaderBackdropPainter(this.t);

  static const _twoPi = math.pi * 2;

  void _glow(Canvas canvas, Offset c, double r, List<Color> colors) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Safety: never paint outside the header
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;
    final a = t * _twoPi;

    // 1) Aurora glows: coral top right (breathes), violet left
    final breathe = 1.0 + 0.1 * math.sin(a * 2);
    _glow(
      canvas,
      Offset(w * 0.98 + math.sin(a) * 22, h * 0.0 + math.cos(a) * 16),
      130 * breathe,
      const [Color(0x59FE8357), Color(0x40A855F7), Color(0x00000000)],
    );
    _glow(
      canvas,
      Offset(w * 0.0 + math.cos(a) * 20, h * 0.35 + math.sin(a) * 18),
      125,
      const [Color(0x5C7E22CE), Color(0x33581C87), Color(0x00000000)],
    );

    // 2) A small dot with an expanding "ping" ring
    final pingC = Offset(w * 0.36, h * 0.26);
    final p = (t * 4) % 1.0; // 4 pings per loop
    canvas.drawCircle(
      pingC,
      3 + p * 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withAlpha(((1 - p) * 90).round()),
    );
    canvas.drawCircle(pingC, 2, Paint()..color = Colors.white.withAlpha(110));

    // 3) Amber dot that pulses near the bottom right
    final pulse = 0.5 + 0.5 * math.sin(a * 5);
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.82),
      3,
      Paint()
        ..color = const Color(0xFFFCD34D).withAlpha((70 + pulse * 120).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    // 4) Floating dots drifting upward
    const dots = [
      [0.12, 0.00, 2.4],
      [0.55, 0.40, 2.0],
      [0.90, 0.70, 2.8],
    ];
    for (final d in dots) {
      final prog = (t + d[1]) % 1.0;
      final y = h - prog * h;
      final x = w * d[0] + math.sin((t + d[1]) * _twoPi) * 8;
      final alpha = (math.sin(prog * math.pi) * 150).round().clamp(0, 255);
      canvas.drawCircle(
        Offset(x, y),
        d[2],
        Paint()..color = const Color(0xFFFFDEAD).withAlpha(alpha),
      );
    }

    // 5) Shimmer sweep (2 passes per loop)
    final s = (t * 2) % 1.0;
    final envelope = math.sin(s * math.pi);
    final bandW = w * 0.45;
    final skew = h * 0.45;
    final x0 = -bandW - skew + s * (w + bandW * 2 + skew);
    final path = Path()
      ..moveTo(x0, 0)
      ..lineTo(x0 + bandW, 0)
      ..lineTo(x0 + bandW - skew, h)
      ..lineTo(x0 - skew, h)
      ..close();
    final peak = (envelope * 26).round().clamp(0, 255);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withAlpha(0),
            Colors.white.withAlpha(peak),
            Colors.white.withAlpha(0),
          ],
        ).createShader(Rect.fromLTWH(x0 - skew, 0, bandW + skew, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderBackdropPainter old) => old.t != t;
}