import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';

/// The signed-in Buyer's orders, from `GET /api/v1/buyer/orders`.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _purple = Color(0xFF3B1F52);
  static const _purpleMid = Color(0xFF7B2FBE);
  static const _bg = Color(0xFFF4F1F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF888888);
  static const _border = Color(0xFFECE6EA);

  List<ApiOrder> _orders = const [];
  bool _loading = true;
  String? _error;
  String? _status;

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
      final orders = await BuyerApi.instance.orders(status: _status);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach Vendo. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filter('All', null),
                  _filter('Placed', 'placed'),
                  _filter('Confirmed', 'confirmed'),
                  _filter('Shipped', 'shipped'),
                  _filter('Delivered', 'delivered'),
                  _filter('Completed', 'completed'),
                  _filter('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorState()
                    : _orders.isEmpty
                        ? const Center(
                            child: Text(
                              'No orders yet.',
                              style: TextStyle(color: _muted),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, index) => _orderCard(_orders[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filter(String label, String? value) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFFEDE5F5),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? _purpleMid : _ink,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        onSelected: (_) {
          setState(() => _status = value);
          _load();
        },
      ),
    );
  }

  Widget _orderCard(ApiOrder order) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
        );
        if (mounted) _load();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.number,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE5F5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: const TextStyle(fontSize: 11, color: _purpleMid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    order.image,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 58,
                      height: 58,
                      color: _border,
                      child: const Icon(Icons.image_not_supported_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.shop,
                        style: const TextStyle(fontSize: 13, color: _ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.itemsCount} item(s) · ${order.placedAtLabel ?? ''}',
                        style: const TextStyle(fontSize: 11.5, color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pay on delivery: ${order.codAmount}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF1A9B5A),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.total,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _purple,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'view details',
                      style: const TextStyle(fontSize: 10.5, color: _purpleMid),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
            const Icon(Icons.cloud_off_rounded, size: 44, color: _muted),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purpleMid),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One order, with the COD amount, delivery address, timeline and the allowed actions.
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _purple = Color(0xFF3B1F52);
  static const _purpleMid = Color(0xFF7B2FBE);
  static const _bg = Color(0xFFF4F1F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF888888);
  static const _border = Color(0xFFECE6EA);
  static const _green = Color(0xFF1A9B5A);

  static const _reasons = <String, String>{
    'changed_mind': 'Changed my mind',
    'ordered_by_mistake': 'Ordered by mistake',
    'delivery_timing': 'Delivery timing no longer works for me',
    'found_elsewhere': 'Found the item elsewhere',
    'other': 'Other',
  };

  ApiOrderDetail? _detail;
  bool _loading = true;
  bool _working = false;
  String? _error;

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
      final detail = await BuyerApi.instance.order(widget.orderId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach Vendo. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final detail = _detail;
    if (detail == null) return;
    String reason = 'changed_mind';
    final detailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('reason-$reason'),
                initialValue: reason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _reasons.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => reason = value);
                },
              ),
              if (reason == 'other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: detailsCtrl,
                  maxLength: 450,
                  decoration: const InputDecoration(
                    labelText: 'Tell us more',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep order'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purpleMid),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final updated = await BuyerApi.instance.cancelOrder(
        widget.orderId,
        detail.order.status,
        reason,
        details: detailsCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _detail = updated);
      _toast('Order cancelled. Reserved stock was restored.');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _working = true);
    try {
      final updated = await BuyerApi.instance.completeOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _detail = updated);
      _toast('Order received. Thank you!');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _detail?.order.number ?? 'Order',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
              : _content(),
    );
  }

  Widget _content() {
    final detail = _detail!;
    final order = detail.order;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.statusLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _purple,
                      ),
                    ),
                  ),
                  Text(
                    order.placedAtLabel ?? '',
                    style: const TextStyle(fontSize: 11.5, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order.shop,
                style: const TextStyle(fontSize: 12.5, color: _ink),
              ),
              if ((detail.moneyStatusLabel ?? '').isNotEmpty)
                Text(
                  'Cash: ${detail.moneyStatusLabel}',
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              const Divider(height: 20),
              Row(
                children: [
                  const Text('Pay on delivery', style: TextStyle(fontSize: 12.5)),
                  const Spacer(),
                  Text(
                    order.codAmount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Items ${order.total} + shipping ${order.shippingFee}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Items',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...detail.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.image,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: _border,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 12.5)),
                            Text(
                              [
                                if ((item.color ?? '').isNotEmpty) item.color!,
                                if ((item.size ?? '').isNotEmpty) item.size!,
                                'x${item.quantity}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      Text(item.price, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery address',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                detail.shippingAddress ?? '—',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              if ((detail.voucherCode ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Voucher ${detail.voucherCode} · -${detail.voucherDiscount ?? ''}',
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ],
          ),
        ),
        if (detail.timeline.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...detail.timeline.map(
                  (step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 15, color: _purpleMid),
                        const SizedBox(width: 8),
                        Text(step, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (order.canCancel)
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _working ? null : _cancel,
              child: const Text('Cancel order'),
            ),
          ),
        if (order.status == 'delivered')
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purpleMid),
              onPressed: _working ? null : _complete,
              child: const Text('Order received'),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
