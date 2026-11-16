import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/orders/screens/order_detail_screen.dart';
import 'package:vendo_buyer/features/shared/offline_banner.dart';

/// The signed-in Buyer's orders, from `GET /api/v1/buyer/orders`.
///
/// Laid out like the web "My orders" page: the same seven status tabs with their
/// counts on top, then one card per order with the shop and status in the header,
/// the items in the middle and the total plus the web's action in the footer.
class OrdersScreen extends StatefulWidget {
  /// Opens the list on one of the web's tabs: placed, to_ship, in_transit,
  /// delivered, returns or cancelled. Null starts on All.
  final String? initialTab;

  const OrdersScreen({super.key, this.initialTab});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _plum = Color(0xFF402143);
  static const _plumMid = Color(0xFF52245B);
  static const _bg = Color(0xFFF7F5F9);
  static const _band = Color(0xFFF6F2F7);
  static const _countBg = Color(0xFFF0E9F2);
  static const _ink = Color(0xFF2B1730);
  static const _body = Color(0xFF5B4A60);
  static const _muted = Color(0xFF7A6A7E);
  static const _lite = Color(0xFF8A7A8E);
  static const _border = Color(0xFFEEE6EF);
  static const _qty = Color(0xFF5B5BD6);
  static const _green = Color(0xFF1A9B5A);
  static const _greenDeep = Color(0xFF2E6B46);

  List<ApiOrder> _orders = const [];

  /// The tabs and their counts, exactly the seven the web page shows.
  List<ApiOrderTab> _tabs = const [];

  bool _loading = true;
  String? _error;
  String _tab = 'all';

  /// Set when the list came from the device instead of Vendo.
  DateTime? _offlineSince;

  /// Drops the answer of a tab the Buyer already tapped away from.
  int _requestId = 0;

  // The tabs count every order, so the list can page on until it matches them.
  int _page = 1;
  int _lastPage = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ?? 'all';
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final requestId = ++_requestId;
    setState(() {
      _loadingMore = false;
      if (!silent) {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await BuyerApi.instance.orders(tab: _tab);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _orders = page.orders;
        if (page.tabs.isNotEmpty) _tabs = page.tabs;
        _page = page.page;
        _lastPage = page.lastPage;
        _offlineSince = null;
        _error = null;
        _loading = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      // Offline: show the orders saved on this device instead of an error.
      final cached = await BuyerApi.instance.cachedOrders(tab: _tab);
      if (!mounted || requestId != _requestId) return;
      if (cached == null) {
        setState(() {
          _error =
              'Could not reach Vendo and no saved orders are on this device yet.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _orders = cached.items;
        if (cached.tabs.isNotEmpty) _tabs = cached.tabs;
        _page = 1;
        _lastPage = 1;
        _offlineSince = cached.cachedAt;
        _error = null;
        _loading = false;
      });
    }
  }

  void _selectTab(String key) {
    if (_tab == key) return;
    setState(() => _tab = key);
    _load();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    final tab = _tab;
    final requestId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final next = await BuyerApi.instance.orders(tab: tab, page: _page + 1);
      if (!mounted || tab != _tab || requestId != _requestId) return;
      setState(() {
        _orders = [..._orders, ...next.orders];
        if (next.tabs.isNotEmpty) _tabs = next.tabs;
        _page = next.page;
        _lastPage = next.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || tab != _tab || requestId != _requestId) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more orders.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _plum,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _tabStrip(),
          if (_offlineSince != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: OfflineBanner(
                savedAt: _offlineSince,
                onRetry: _loading ? null : _load,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _errorState()
                : _orders.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    color: _plum,
                    onRefresh: () => _load(silent: true),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _orders.length + (_page < _lastPage ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => index == _orders.length
                          ? _loadMoreButton()
                          : _orderCard(_orders[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Tabs (the web's seven pills in a bordered strip, with their counts) ──
  Widget _tabStrip() {
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    );

    // Until the API answers there are no labels to draw, so the strip keeps its
    // shape instead of jumping when the list arrives.
    if (_tabs.isEmpty) {
      if (!_loading) return const SizedBox.shrink();
      return Container(
        height: 42,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        alignment: Alignment.center,
        decoration: decoration,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: decoration,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final tab in _tabs) _tabPill(tab)]),
      ),
    );
  }

  Widget _tabPill(ApiOrderTab tab) {
    final selected = _tab == tab.key;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectTab(tab.key),
      child: Container(
        height: 34,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _plum : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : _body,
              ),
            ),
            // The web shows every tab's count, not just the open one.
            if (tab.count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : _countBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${tab.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _body,
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

  String get _tabLabel {
    for (final tab in _tabs) {
      if (tab.key == _tab) return tab.label;
    }
    return '';
  }

  String get _emptyTitle {
    switch (_tab) {
      case 'all':
        return 'You have no orders yet';
      case 'returns':
        return 'No returns yet';
      default:
        final label = _tabLabel.toLowerCase();
        return label.isEmpty ? 'No orders' : 'No orders in $label';
    }
  }

  String get _emptyText {
    switch (_tab) {
      case 'all':
        return 'When you place an order it shows up here, with live updates as the seller and logistics move it along.';
      case 'returns':
        return 'Return requests and returned orders appear here. You can ask for a return from a delivered order.';
      default:
        return 'Orders move here automatically as their status changes.';
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _band,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 26,
                color: _lite,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status chip colors ───────────────────────────────────────────────────
  ({Color bg, Color fg}) _statusColors(String label) {
    final value = label.toLowerCase();
    if (value.contains('cancel') ||
        value.contains('return') ||
        value.contains('fail') ||
        value.contains('refund')) {
      return (bg: const Color(0xFFFDECEE), fg: const Color(0xFFA32B43));
    }
    if (value.contains('deliver') || value.contains('complete')) {
      return (bg: const Color(0xFFE6F4EA), fg: _greenDeep);
    }
    if (value.contains('transit') ||
        value.contains('shipped') ||
        value.contains('out for')) {
      return (bg: const Color(0xFFE8EEFD), fg: const Color(0xFF3B5BDB));
    }
    if (value.contains('placed') || value.contains('pending')) {
      return (bg: const Color(0xFFFBEFC9), fg: const Color(0xFF8A6410));
    }
    // Ready for pickup, assigned to rider, packed, …
    return (bg: const Color(0xFFEDE5F5), fg: const Color(0xFF6B3FA0));
  }

  ({Color bg, Color fg}) _pillColors(String tone) {
    return switch (tone) {
      'pending' => (bg: const Color(0xFFFBF3DC), fg: const Color(0xFF7A5A0C)),
      'rejected' => (bg: const Color(0xFFFDF1F3), fg: const Color(0xFFA32B43)),
      'done' => (bg: const Color(0xFFEAF5EE), fg: _greenDeep),
      _ => (bg: const Color(0xFFF5ECF6), fg: _plumMid),
    };
  }

  String _orderLabel(String number) {
    return number.toLowerCase().startsWith('order') ? number : 'Order $number';
  }

  // ── One order card ───────────────────────────────────────────────────────
  Widget _orderCard(ApiOrder order) {
    final colors = _statusColors(order.statusLabel);
    final placedAt = order.placedAtLabel ?? '';
    final reason = order.cancelReason ?? '';

    void openDetails() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      );
      if (mounted) _load(silent: true);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: shop + order number on the left, status and return pills right.
          InkWell(
            onTap: openDetails,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: _lite,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.shop.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _orderLabel(order.number),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: _lite),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          order.displayStatusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.fg,
                          ),
                        ),
                      ),
                      if (order.returnPill != null) ...[
                        const SizedBox(height: 4),
                        _returnPill(order.returnPill!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _border),

          // Why it was cancelled, like the web card's pink strip.
          if (reason.isNotEmpty) ...[
            Container(
              width: double.infinity,
              color: const Color(0xFFFDF6F7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Reason: $reason',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7D3243)),
              ),
            ),
            const Divider(height: 1, color: _border),
          ],

          // Items.
          InkWell(
            onTap: openDetails,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _thumb(order.image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.itemsCount} ${order.itemsCount == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _ink,
                          ),
                        ),
                        if (placedAt.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Placed $placedAt',
                              style: const TextStyle(fontSize: 12, color: _qty),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _border),

          // Footer: total on the left, the web's action on the right.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '${order.itemsCount} ${order.itemsCount == 1 ? 'item' : 'items'}, total ',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                            TextSpan(
                              text: order.total,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: _plumMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pay on delivery: ${order.codAmount}',
                        style: const TextStyle(fontSize: 11.5, color: _green),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: order.status == 'delivered'
                        ? _greenDeep
                        : _plum,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: openDetails,
                  child: Text(order.actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadMoreButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _plum,
          side: const BorderSide(color: _border),
          backgroundColor: Colors.white,
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: _loadingMore ? null : _loadMore,
        child: _loadingMore
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Load more orders'),
      ),
    );
  }

  Widget _returnPill(ApiOrderPill pill) {
    final colors = _pillColors(pill.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        pill.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.fg,
        ),
      ),
    );
  }

  Widget _thumb(String url) {
    final fallback = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      color: _band,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: _lite,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _lite),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _plum),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
