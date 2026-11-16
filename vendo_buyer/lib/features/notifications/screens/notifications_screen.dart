import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/home/widgets/buyer_nav_bar.dart';
import 'package:vendo_buyer/features/orders/screens/order_detail_screen.dart';
import 'package:vendo_buyer/features/shared/offline_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors taken from the Stitch design (DESIGN.md / code.html)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const surface = Color(0xFFFFF7FF); // page background
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF120019); // headings
  static const primaryContainer = Color(0xFF2E1535); // deep plum
  static const secondary = Color(0xFF775A0D); // gold text
  static const secondaryContainer = Color(0xFFFDD57E);
  static const onSurfaceVariant = Color(0xFF4C444C);
  static const outline = Color(0xFF7D747C);
  static const outlineVariant = Color(0xFFCEC3CC);
  static const surfaceContainer = Color(0xFFF7E9FE);
  static const unreadTint = Color(0xFFFBF6FC);

  // Status colors (parcel progress)
  static const statusInfo = Color(0xFF3B5BDB); // placed / packed / assigned
  static const statusTransit = Color(0xFF775A0D); // shipped / out for delivery
  static const statusDone = Color(0xFF2F9E44); // delivered
  static const statusBad = Color(0xFFC92A2A); // cancelled / returned

  // The design uses these at partial opacity for borders.
  static final border = outlineVariant.withValues(alpha: 0.4);
  static final divider = outlineVariant.withValues(alpha: 0.2);
}

/// Icon for a notification kind. Mirrors the grouping the web buyer page uses,
/// so both surfaces present the same record the same way.
IconData _kindIcon(String? type) {
  final value = (type ?? '').toLowerCase();
  if (value.contains('warning') ||
      value.contains('violation') ||
      value.contains('suspend')) {
    return Icons.gpp_maybe_outlined;
  }
  if (value.contains('announcement') || value.contains('policy')) {
    return Icons.campaign_outlined;
  }
  if (value.contains('review') || value.contains('rating')) {
    return Icons.star_border_rounded;
  }
  if (value.contains('message') || value.contains('chat')) {
    return Icons.chat_bubble_outline_rounded;
  }
  if (value.contains('order') ||
      value.contains('shipment') ||
      value.contains('delivery') ||
      value.contains('cancel')) {
    return Icons.local_shipping_outlined;
  }
  return Icons.notifications_none_rounded;
}

// ─────────────────────────────────────────────────────────────────────────────
// Parcel status
//
// One parcel = ONE card. Every update for the same parcel (placed, packed,
// assigned to rider, shipped, out for delivery, delivered…) is folded into that
// card, and only its status label + color + progress step change — like the
// Shopee app. The older updates stay available under "History".
//
//   Order placed → Packed → Assigned to rider → Shipped → Out for delivery
//   → Delivered   (or Cancelled / Returned)
//
// The status comes from the order the notification belongs to (the API sends
// its real `status` on each notification); only a notification with no order,
// or an order status this app does not know yet, falls back to the wording.
// ─────────────────────────────────────────────────────────────────────────────
class _ParcelStatus {
  final String label;
  final IconData icon;
  final Color color;

  /// Position in the progress tracker, or -1 for cancelled / returned.
  final int step;

  const _ParcelStatus(this.label, this.icon, this.color, this.step);
}

const _trackerSteps = <String>[
  'Placed',
  'Packed',
  'Rider assigned',
  'Shipped',
  'Out for delivery',
  'Delivered',
];

/// The card status for the order the notification belongs to. Null when the
/// notification has no order (an announcement, a chat message) or carries a
/// status this app does not know, so the caller can fall back to the wording.
_ParcelStatus? _orderParcelStatus(ApiNotification item) {
  switch ((item.orderStatus ?? '').toLowerCase()) {
    case 'placed':
      return const _ParcelStatus(
        'Order placed',
        Icons.receipt_long_outlined,
        _C.statusInfo,
        0,
      );
    case 'confirmed':
    case 'preparing':
    case 'ready_for_pickup':
      return const _ParcelStatus(
        'Packed',
        Icons.inventory_2_outlined,
        _C.statusInfo,
        1,
      );
    case 'assigned_to_rider':
      return const _ParcelStatus(
        'Assigned to rider',
        Icons.two_wheeler_outlined,
        _C.statusInfo,
        2,
      );
    case 'picked_up':
    case 'at_sorting_center':
    case 'sorted':
    case 'to_soc5':
    case 'to_soc6':
    case 'in_transit_to_hub':
    case 'at_destination_hub':
      return const _ParcelStatus(
        'Shipped',
        Icons.local_shipping_outlined,
        _C.statusTransit,
        3,
      );
    case 'out_for_delivery':
      return const _ParcelStatus(
        'Out for delivery',
        Icons.delivery_dining_outlined,
        _C.statusTransit,
        4,
      );
    case 'delivered':
      return const _ParcelStatus(
        'Delivered',
        Icons.check_circle_outline_rounded,
        _C.statusDone,
        5,
      );
    case 'completed':
      return const _ParcelStatus(
        'Completed',
        Icons.done_all_rounded,
        _C.statusDone,
        5,
      );
    case 'delivery_failed':
      return const _ParcelStatus(
        'Delivery failed',
        Icons.error_outline_rounded,
        _C.statusBad,
        -1,
      );
    case 'cancelled':
      return const _ParcelStatus(
        'Cancelled',
        Icons.cancel_outlined,
        _C.statusBad,
        -1,
      );
    case 'returned':
      return const _ParcelStatus(
        'Returned',
        Icons.assignment_return_outlined,
        _C.statusBad,
        -1,
      );
    default:
      return null;
  }
}

/// Returns the parcel status, or null when this is not an order/parcel
/// notification (announcements, messages, reviews, …).
_ParcelStatus? _parcelStatusOf(ApiNotification item) {
  final fromOrder = _orderParcelStatus(item);
  if (fromOrder != null) return fromOrder;

  final type = (item.type ?? '').toLowerCase();
  final text = '$type ${item.title} ${item.message}'.toLowerCase();

  final orderRelated =
      text.contains('order') ||
      text.contains('parcel') ||
      text.contains('shipment') ||
      text.contains('shipped') ||
      text.contains('deliver') ||
      text.contains('rider') ||
      text.contains('cancel') ||
      text.contains('return');
  if (!orderRelated) return null;

  if (text.contains('cancel')) {
    return const _ParcelStatus(
      'Cancelled',
      Icons.cancel_outlined,
      _C.statusBad,
      -1,
    );
  }
  if (text.contains('return') || text.contains('refund')) {
    return const _ParcelStatus(
      'Returned',
      Icons.assignment_return_outlined,
      _C.statusBad,
      -1,
    );
  }
  // "VND-00026: Completed" — without this the completed order fell through to
  // the "Order placed" default below.
  if (text.contains('complete')) {
    return const _ParcelStatus(
      'Completed',
      Icons.done_all_rounded,
      _C.statusDone,
      5,
    );
  }
  if (text.contains('delivered')) {
    return const _ParcelStatus(
      'Delivered',
      Icons.check_circle_outline_rounded,
      _C.statusDone,
      5,
    );
  }
  if (text.contains('out for delivery')) {
    return const _ParcelStatus(
      'Out for delivery',
      Icons.delivery_dining_outlined,
      _C.statusTransit,
      4,
    );
  }
  if (text.contains('rider') || text.contains('assigned')) {
    return const _ParcelStatus(
      'Assigned to rider',
      Icons.two_wheeler_outlined,
      _C.statusInfo,
      2,
    );
  }
  if (text.contains('shipped') || text.contains('shipping')) {
    return const _ParcelStatus(
      'Shipped',
      Icons.local_shipping_outlined,
      _C.statusTransit,
      3,
    );
  }
  if (text.contains('packed') ||
      text.contains('preparing') ||
      text.contains('ready to ship')) {
    return const _ParcelStatus(
      'Packed',
      Icons.inventory_2_outlined,
      _C.statusInfo,
      1,
    );
  }
  return const _ParcelStatus(
    'Order placed',
    Icons.receipt_long_outlined,
    _C.statusInfo,
    0,
  );
}

/// Short helper line shown under the title, like "Click to track your order".
String _parcelHint(_ParcelStatus status) {
  if (status.label == 'Completed') {
    return 'Order completed. Tap to see the details.';
  }
  switch (status.step) {
    case 5:
      return 'Your parcel has arrived. Tap to see the details.';
    case 4:
      return 'Your rider is on the way. Tap to track your order.';
    case 2:
    case 3:
      return 'Shipping info · Click to track your order';
    case -1:
      return 'Tap to see what happened to this order.';
    default:
      return 'Tap to view your order.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parcel grouping
//
// All notifications about the same parcel share one key, so they collapse into
// a single card. The list from the API is newest first, so the first item of a
// group is its current status.
//
// The key is the order id the API sends with the notification, so two orders of
// the same product stay two cards and every update of one order lands in one.
// Older payloads without an order fall back to the order reference in the text
// ("#10234", "Order VND-10234"), then to the product (name + picture), and a
// notification that gives none of those stays its own card.
// ─────────────────────────────────────────────────────────────────────────────
final _orderRefPattern = RegExp(
  r'(?:#\s*|(?:order|parcel)\s*(?:no\.?|number|id)?\s*[:#]?\s*)((?=[A-Za-z0-9\-]*\d)[A-Za-z0-9\-]{3,})',
  caseSensitive: false,
);

String? _parcelKeyOf(ApiNotification item) {
  final orderId = item.orderId;
  if (orderId != null) return 'order:$orderId';

  final match = _orderRefPattern.firstMatch('${item.title} ${item.message}');
  if (match != null) return 'order:${match.group(1)!.toUpperCase()}';

  final name = item.productName;
  if (name != null && name.isNotEmpty) {
    return 'product:$name|${item.productImage ?? ''}';
  }
  return null;
}

/// One parcel and every notification about it, newest first.
class _ParcelGroup {
  final String key;
  final List<ApiNotification> items;

  const _ParcelGroup(this.key, this.items);

  /// The most recent update: it decides the card's status.
  ApiNotification get latest => items.first;

  bool get unread => items.any((entry) => !entry.read);
}

/// Folds the flat notification list into entries: a [_ParcelGroup] for parcel
/// notifications (one per parcel) or a plain [ApiNotification] for the rest.
/// A group sits where its newest update was.
List<Object> _buildEntries(List<ApiNotification> items) {
  final buckets = <String, List<ApiNotification>>{};
  final order = <Object>[];

  for (final item in items) {
    final isParcel = _parcelStatusOf(item) != null;
    if (!isParcel) {
      order.add(item);
      continue;
    }
    final key = _parcelKeyOf(item) ?? 'single:${item.id}';
    final bucket = buckets[key];
    if (bucket == null) {
      buckets[key] = [item];
      order.add(key);
    } else {
      bucket.add(item);
    }
  }

  return [
    for (final entry in order)
      entry is String ? _ParcelGroup(entry, buckets[entry]!) : entry,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Product picture
//
// The photo of what the parcel holds, so a buyer can tell one order from
// another at a glance. The server resolves it from the notification's link —
// the buyer order page (its first item) or a product page — and sends it as
// `product.image`; `product.name` comes along for the card's caption.
// Announcements and account notices point at nothing on sale, so they carry no
// product and keep their kind icon.
// ─────────────────────────────────────────────────────────────────────────────
String? _productImageOf(ApiNotification item) {
  final image = item.productImage;
  return image == null || image.isEmpty ? null : image;
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _ProductThumb({required this.imageUrl, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _C.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Icon(Icons.image_outlined, size: size * 0.4, color: _C.outline),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
/// The signed-in Buyer's notifications, from `GET /api/v1/buyer/notifications`.
///
/// These are the same `notifications` rows the web buyer page lists, so the two
/// surfaces stay in step: a notification created on either side appears here,
/// and reading one on either side clears it for both. Read state is written
/// through `POST /notifications/{id}/read`, "mark all" through
/// `POST /notifications/read-all`.
///
/// Order/parcel notifications are drawn as parcel cards: ONE card per parcel,
/// with a status chip (placed, packed, assigned to rider, shipped, out for
/// delivery, delivered, cancelled…) that changes as the parcel moves along, and
/// the product picture on the right.
///
/// The list refreshes when the screen opens, when it becomes the visible tab,
/// on pull-to-refresh, and every [_pollEvery] while visible, so a status change
/// made on the web or by the rider shows up without restarting the app.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.isActive = true});

  /// False while this screen sits in a tab that is not on top. Polling pauses
  /// so a hidden tab never keeps hitting Vendo.
  final bool isActive;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pollEvery = Duration(seconds: 30);

  final _api = BuyerApi.instance;

  List<ApiNotification> _items = const [];
  int _unread = 0;
  bool _unreadOnly = false;
  bool _loading = true;
  bool _inFlight = false;
  String? _error;

  /// Set when the list came from the device instead of Vendo.
  DateTime? _cachedAt;

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) _load(silent: true);
      _startPolling();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = null;
    if (!widget.isActive) return;
    _poll = Timer.periodic(_pollEvery, (_) => _load(silent: true));
  }

  /// Fetches the list. A silent pass (polling) never shows a spinner, never
  /// clears what is on screen, and never announces itself.
  Future<void> _load({bool silent = false}) async {
    if (silent && _inFlight) return;
    _inFlight = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final feed = await _api.notifications(unreadOnly: _unreadOnly);
      if (!mounted) return;
      setState(() {
        _items = feed.items;
        _unread = feed.unreadCount;
        _cachedAt = null;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final cached = await _api.cachedNotifications();
      if (!mounted) return;

      // Something is already on screen: keep it and say why it may be stale.
      if (_items.isNotEmpty) {
        setState(() => _loading = false);
        if (!silent) _toast('Could not reach Vendo — showing the last update.');
        return;
      }

      if (cached != null) {
        setState(() {
          _items = _unreadOnly
              ? cached.items.where((item) => !item.read).toList()
              : cached.items;
          _unread = cached.items.where((item) => !item.read).length;
          _cachedAt = cached.cachedAt;
          _error = null;
          _loading = false;
        });
        return;
      }

      setState(() {
        _loading = false;
        _error = error is BuyerApiException
            ? error.message
            : 'Could not reach Vendo. Check your connection and try again.';
      });
    } finally {
      _inFlight = false;
    }
  }

  void _setFilter(bool unreadOnly) {
    if (_unreadOnly == unreadOnly) return;
    setState(() {
      _unreadOnly = unreadOnly;
      _items = const [];
      _cachedAt = null;
      _error = null;
      _loading = true;
    });
    _load();
  }

  /// Opens the order behind a notification and marks it read for both apps.
  /// Notices that are not about an order (announcements, support replies,
  /// reviews) still open the message sheet, since they have no order screen.
  Future<void> _open(ApiNotification item) async {
    unawaited(_markRead([item]));
    final orderId = item.orderId;
    if (orderId != null) {
      await _openOrder(orderId);
      return;
    }
    _showDetails(item);
  }

  /// Opens the order a parcel card stands for — no sheet in between — and marks
  /// every update of that parcel read.
  Future<void> _openParcel(_ParcelGroup group) async {
    unawaited(_markRead(group.items));
    final orderId = group.latest.orderId;
    if (orderId != null) {
      await _openOrder(orderId);
      return;
    }
    // No order on the payload (an older server): keep the status and history.
    _showDetails(group.latest, history: group.items);
  }

  /// The same screen the Orders tab opens, so the tapped card leads to the
  /// order's status, items and tracking.
  Future<void> _openOrder(int orderId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
    );
    if (mounted) _load(silent: true);
  }

  /// Marks the given notifications read locally right away, then on Vendo.
  Future<void> _markRead(List<ApiNotification> targets) async {
    final unreadItems = targets.where((entry) => !entry.read).toList();
    if (unreadItems.isEmpty) return;

    final ids = unreadItems.map((entry) => entry.id).toSet();
    setState(() {
      _items = _items
          .map(
            (entry) =>
                ids.contains(entry.id) ? entry.copyWith(read: true) : entry,
          )
          .where((entry) => !_unreadOnly || !entry.read)
          .toList();
      _unread = _unread >= ids.length ? _unread - ids.length : 0;
    });

    try {
      int? unread;
      for (final entry in unreadItems) {
        unread = await _api.markNotificationRead(entry.id);
      }
      if (!mounted) return;
      if (unread != null) setState(() => _unread = unread!);
    } catch (_) {
      // Offline or rejected: the next refresh puts the server's truth back.
      if (mounted) _load(silent: true);
    }
  }

  Future<void> _markAllRead() async {
    final snapshot = _items;
    final previousUnread = _unread;
    setState(() {
      _items = _unreadOnly
          ? const []
          : _items.map((item) => item.copyWith(read: true)).toList();
      _unread = 0;
    });

    try {
      await _api.markAllNotificationsRead();
      await _load(silent: true);
    } on BuyerApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _items = snapshot;
        _unread = previousUnread;
      });
      _toast(error.message);
    } catch (_) {
      // No signal: the outbox marks everything read once Vendo is reachable.
      await _api.queueMarkAllNotificationsReadOffline();
      _toast('Offline — everything will be marked read when Vendo is back.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Details sheet for a notification with no order screen behind it. For a
  /// parcel (an older payload), [history] holds every update of that parcel
  /// (newest first) and is listed under the progress tracker.
  void _showDetails(
    ApiNotification item, {
    List<ApiNotification> history = const [],
  }) {
    final status = _parcelStatusOf(item);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _C.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status != null) ...[
                          _StatusChip(status: status),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (status == null) ...[
                              Icon(
                                _kindIcon(item.type),
                                size: 20,
                                color: _C.secondary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  color: _C.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_productImageOf(item) != null) ...[
                    const SizedBox(width: 12),
                    _ProductThumb(imageUrl: _productImageOf(item), size: 72),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.message,
                style: const TextStyle(
                  color: _C.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              if (status != null && status.step >= 0) ...[
                const SizedBox(height: 16),
                _ProgressTracker(step: status.step),
              ],
              if (history.length > 1) ...[
                const SizedBox(height: 8),
                const Divider(height: 24, color: Color(0x1ACEC3CC)),
                const Text(
                  'Updates',
                  style: TextStyle(
                    color: _C.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in history) _HistoryRow(item: entry),
              ],
              const SizedBox(height: 14),
              Text(
                item.timeAgo ?? '',
                style: const TextStyle(color: _C.outline, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // As a tab the floating nav bar sits over the page, so leave room for it.
    final bottomClearance = Navigator.of(context).canPop()
        ? 24.0
        : 24.0 + kBuyerNavBarClearance + MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.surface,
        body: Column(
          children: [
            _Header(
              unread: _unread,
              onMarkAllRead: _unread > 0 ? _markAllRead : null,
            ),
            Expanded(
              child: RefreshIndicator(
                color: _C.primaryContainer,
                onRefresh: () => _load(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomClearance),
                  children: [
                    if (_cachedAt != null) ...[
                      OfflineBanner(
                        savedAt: _cachedAt,
                        onRetry: _loading ? null : () => _load(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _FilterTabs(
                      unreadOnly: _unreadOnly,
                      unread: _unread,
                      onChanged: _setFilter,
                    ),
                    const SizedBox(height: 12),
                    ..._content(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_loading && _items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null && _items.isEmpty) {
      return [
        _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load notifications',
          text: _error!,
          actionLabel: 'Try again',
          onAction: () => _load(),
        ),
      ];
    }

    if (_items.isEmpty) {
      return [
        _EmptyState(
          icon: _unreadOnly
              ? Icons.mark_email_read_outlined
              : Icons.notifications_none_rounded,
          title: _unreadOnly ? 'You are all caught up' : 'No notifications yet',
          text: _unreadOnly
              ? 'There are no unread notifications.'
              : 'Order updates, seller messages and announcements from Vendo will appear here.',
          actionLabel: _unreadOnly ? 'See all notifications' : null,
          onAction: _unreadOnly ? () => _setFilter(false) : null,
        ),
      ];
    }

    return [
      for (final entry in _buildEntries(_items)) ...[
        if (entry is _ParcelGroup)
          _ParcelCard(group: entry, onTap: () => _openParcel(entry))
        else
          _NotificationCard(
            item: entry as ApiNotification,
            onTap: () => _open(entry),
          ),
        const SizedBox(height: 8),
      ],
      const _EndMarker(),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: back (when pushed), title, unread count, "mark all as read"
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int unread;
  final VoidCallback? onMarkAllRead;

  const _Header({required this.unread, required this.onMarkAllRead});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.95),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2E1535),
            blurRadius: 12,
            spreadRadius: -4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: EdgeInsets.only(left: canPop ? 4 : 16, right: 8),
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    color: _C.primary,
                    tooltip: 'Back',
                    visualDensity: VisualDensity.compact,
                  ),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: _C.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.3,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 20,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _C.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unread new',
                      style: const TextStyle(
                        color: _C.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (onMarkAllRead != null)
                  TextButton(
                    onPressed: onMarkAllRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: _C.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
// All / Unread filter (server-side, matching the web buyer page)
// ─────────────────────────────────────────────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  final bool unreadOnly;
  final int unread;
  final ValueChanged<bool> onChanged;

  const _FilterTabs({
    required this.unreadOnly,
    required this.unread,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              _tab('All', !unreadOnly, null, () => onChanged(false)),
              _tab(
                'Unread',
                unreadOnly,
                unread > 0 ? '$unread' : null,
                () => onChanged(true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, bool active, String? count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _C.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? _C.white : _C.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.2)
                      : _C.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    color: active ? _C.white : _C.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card decoration
// ─────────────────────────────────────────────────────────────────────────────
BoxDecoration _cardDecoration() => BoxDecoration(
  color: _C.white,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: _C.border),
  boxShadow: const [
    BoxShadow(
      color: Color(0x0A2E1535),
      blurRadius: 8,
      spreadRadius: -2,
      offset: Offset(0, 2),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Status chip, e.g. "Out for delivery"
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final _ParcelStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parcel card: ONE card per parcel. Its status chip follows the latest update.
//
//   ┌──────────────────────────────────────────┐
//   │ [Out for delivery]                 ┌────┐│
//   │ Parcel Shipped Out                 │ img││
//   │ Shipping info · Click to track…    └────┘│
//   │ 16:43   History >                        │
//   └──────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────
class _ParcelCard extends StatelessWidget {
  final _ParcelGroup group;
  final VoidCallback onTap;

  const _ParcelCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Everything on the card comes from the newest update of this parcel.
    final item = group.latest;
    final unread = group.unread;
    final status = _parcelStatusOf(item)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration().copyWith(
            color: unread ? _C.unreadTint : _C.white,
          ),
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
                        Row(
                          children: [
                            _StatusChip(status: status),
                            if (unread) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: _C.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _C.primary,
                            fontSize: 14,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        if (item.productName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.productName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _parcelHint(status),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // The parcel's product, so the buyer can tell which order this is.
                  _ProductThumb(imageUrl: _productImageOf(item), size: 64),
                ],
              ),
              const SizedBox(height: 10),
              // Footer spans the whole card: time on the left, History on the
              // right corner.
              Row(
                children: [
                  Text(
                    item.timeAgo ?? '',
                    style: const TextStyle(color: _C.outline, fontSize: 11),
                  ),
                  const Spacer(),
                  const Text(
                    'View order',
                    style: TextStyle(
                      color: _C.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: _C.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One line of a parcel's history in the details sheet
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final ApiNotification item;

  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = _parcelStatusOf(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status?.icon ?? Icons.circle_outlined,
            size: 15,
            color: status?.color ?? _C.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status?.label ?? item.title,
              style: const TextStyle(
                color: _C.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.timeAgo ?? '',
            style: const TextStyle(color: _C.outline, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress tracker used in the details sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressTracker extends StatelessWidget {
  final int step;

  const _ProgressTracker({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _trackerSteps.length; i++)
          _row(i, done: i <= step, current: i == step),
      ],
    );
  }

  Widget _row(int index, {required bool done, required bool current}) {
    final isLast = index == _trackerSteps.length - 1;
    final color = done ? _C.statusDone : _C.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: done ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _trackerSteps[index],
              style: TextStyle(
                color: done ? _C.primary : _C.outline,
                fontSize: 12,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One regular notification (announcement, message, review, …)
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final ApiNotification item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration().copyWith(
            color: unread ? _C.unreadTint : _C.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Not about a parcel, but still about a product (a review reply,
              // for example): show the product, otherwise the kind icon.
              if (_productImageOf(item) != null)
                _ProductThumb(imageUrl: _productImageOf(item), size: 38)
              else
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unread ? _C.secondaryContainer : _C.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _kindIcon(item.type),
                    size: 19,
                    color: unread ? _C.secondary : _C.outline,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.primary,
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          item.timeAgo ?? '',
                          style: const TextStyle(
                            color: _C.outline,
                            fontSize: 11,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _C.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _C.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: _C.outline),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: _C.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// End of list marker
// ─────────────────────────────────────────────────────────────────────────────
class _EndMarker extends StatelessWidget {
  const _EndMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          const Text(
            'No more notifications',
            style: TextStyle(
              color: _C.outline,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 2,
            decoration: BoxDecoration(
              color: _C.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
