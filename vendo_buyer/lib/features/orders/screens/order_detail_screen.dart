import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/messages/screens/seller_chat_screen.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';
import 'package:vendo_buyer/features/seller_page/screens/api_seller_screen.dart';
import 'package:vendo_buyer/features/shared/offline_banner.dart';

// The web order page's palette (buyer/orders/show.blade.php), so the app reads the same.
class _C {
  static const purple = Color(0xFF3B1F52);
  static const plum = Color(0xFF402143);
  static const plumMid = Color(0xFF52245B);
  static const accent = Color(0xFF805487);
  static const bg = Color(0xFFF4F1F8);
  static const ink = Color(0xFF2B1730);
  static const body = Color(0xFF3D2A42);
  static const muted = Color(0xFF7A6A7E);
  static const faint = Color(0xFF8A7A8E);
  static const border = Color(0xFFEEE6EF);
  static const headBg = Color(0xFFF6F2F7);
  static const soft = Color(0xFFFAF5FA);
  static const green = Color(0xFF2E6B46);
  static const greenSoft = Color(0xFFEAF5EE);
  static const danger = Color(0xFFA32B43);
  static const dangerSoft = Color(0xFFFDF1F3);
  static const warning = Color(0xFF7A5A0C);
  static const warningSoft = Color(0xFFFBF3DC);
  static const star = Color(0xFFE8873A);
}

/// One order, laid out like the web order page: status, progress rail, items with
/// their reviews, order updates, summary, address, seller, tracking and the return
/// window. All of it comes from `GET /api/v1/buyer/orders/{id}`, the same row the
/// web reads, so the two pages always show the same state.
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  ApiOrderDetail? _detail;
  bool _loading = true;
  bool _working = false;
  String? _error;

  /// Set when the page came from the device instead of Vendo.
  DateTime? _offlineSince;

  /// The Buyer's token for the private packed-item photo, read once per screen.
  Future<Map<String, String>>? _pickupPhotoHeaders;

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
      // Offline: keep showing the last state saved on this device.
      final cached = await BuyerApi.instance.cachedOrder(widget.orderId);
      if (!mounted) return;
      if (cached == null) {
        setState(() {
          _error =
              'Could not reach Vendo and this order is not saved on this device yet.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _detail = cached.detail;
        _offlineSince = cached.cachedAt;
        _error = null;
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChat() async {
    final seller = _detail?.seller;
    if (seller == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerChatScreen(
          sellerId: seller.id,
          sellerName: seller.name,
          orderId: widget.orderId,
        ),
      ),
    );
  }

  Future<void> _openProduct(ApiOrderItem item) async {
    if (item.productId <= 0) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ApiProductScreen(productId: item.productId, title: item.name),
      ),
    );
  }

  Future<void> _openShop() async {
    final seller = _detail?.seller;
    if (seller == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiSellerScreen(sellerId: seller.id, name: seller.name),
      ),
    );
  }

  /// The rider's photo is private, so the token travels with the image request.
  Future<void> _showDeliveryProof() async {
    Map<String, String> headers;
    try {
      headers = await BuyerApi.instance.mediaHeaders();
    } catch (_) {
      if (mounted) _toast('Could not open the photo. Check your connection.');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Delivery proof',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.plum,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _C.muted,
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Image.network(
                BuyerApi.instance.orderDeliveryProofUrl(widget.orderId),
                headers: headers,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'The photo could not be loaded.',
                    style: TextStyle(fontSize: 13, color: _C.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final detail = _detail;
    if (detail == null) return;
    final reasons = detail.cancelReasons;
    final options = reasons.isEmpty
        ? const [ApiOrderReason(key: 'changed_mind', label: 'Changed my mind')]
        : reasons;
    var reason = options.first.key;
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
                items: options
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.label,
                          overflow: TextOverflow.ellipsis,
                        ),
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
              style: FilledButton.styleFrom(backgroundColor: _C.plumMid),
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

  Future<void> _completeOrder() async {
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

  Future<void> _review(ApiOrderItem item) async {
    var rating = 0;
    final comment = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSubmit = rating > 0 && comment.text.trim().length >= 10;
          return AlertDialog(
            title: Text(
              'Rate ${item.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _StarPicker(
                      rating: rating,
                      onChanged: (value) =>
                          setDialogState(() => rating = value),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    maxLength: 2000,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Your review',
                      hintText: 'What did you like or dislike?',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  Text(
                    rating == 0
                        ? 'Choose a star rating.'
                        : comment.text.trim().length < 10
                        ? 'Write at least 10 characters.'
                        : 'Ready to submit.',
                    style: TextStyle(
                      fontSize: 11,
                      color: canSubmit ? _C.green : _C.muted,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _C.plumMid),
                onPressed: canSubmit
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Submit review'),
              ),
            ],
          );
        },
      ),
    );

    final text = comment.text.trim();
    if (submitted != true) return;

    setState(() => _working = true);
    try {
      await BuyerApi.instance.reviewOrderItem(item.id, rating, text);
      if (!mounted) return;
      _toast('Review submitted. Thank you!');
      await _load();
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _requestReturn() async {
    final detail = _detail;
    if (detail == null || detail.returnReasons.isEmpty) return;
    var reason = detail.returnReasons.first.key;
    final detailsCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final needsDetails =
              reason == 'other' && detailsCtrl.text.trim().length < 3;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request a return',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _C.plum,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tell the seller what went wrong. They review the request and decide.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _C.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('return-reason-$reason'),
                  initialValue: reason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: detail.returnReasons
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => reason = value);
                  },
                ),
                if (reason == 'other') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsCtrl,
                    maxLength: 450,
                    maxLines: 3,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tell the seller what happened',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _C.plumMid),
                    onPressed: needsDetails
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('Send return request'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final updated = await BuyerApi.instance.requestOrderReturn(
        widget.orderId,
        reason,
        details: detailsCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _detail = updated);
      _toast('Return request sent. The seller will review it.');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _detail?.order.number ?? 'Order',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : _content(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _C.muted),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _C.plumMid),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final detail = _detail!;
    final order = detail.order;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          if (_offlineSince != null) ...[
            OfflineBanner(savedAt: _offlineSince, onRetry: _load),
            const SizedBox(height: 10),
          ],
          _headerCard(detail),
          if (detail.progress.terminalIssue)
            _terminalProgress(detail)
          else if (detail.progress.steps.isNotEmpty)
            _progressCard(detail),
          _itemsCard(detail),
          _updatesCard(detail),
          _summaryCard(detail),
          _addressCard(detail),
          if ((detail.buyerNote ?? '').trim().isNotEmpty)
            _noteCard(detail.buyerNote!),
          if (detail.seller != null) _soldByCard(detail.seller!),
          if (detail.tracking != null) _trackingCard(detail.tracking!),
          if (detail.hasPickupPhoto) _packedPhotoCard(),
          ..._returnSection(detail),
          if (order.status == 'delivered') _confirmReceivedCard(),
          if (order.canCancel) _cancelButton(),
          if (detail.cancelLocked) _cancelLockedNotes(),
        ],
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _card({
    String? title,
    required List<Widget> children,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              color: _C.headBg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _C.plum,
                ),
              ),
            ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(ApiOrderDetail detail) {
    final order = detail.order;
    return _card(
      children: [
        Row(
          children: [
            Flexible(child: _statusBadge(order.status, order.statusLabel)),
            const Spacer(),
            if ((order.placedAtLabel ?? '').isNotEmpty)
              Text(
                order.placedAtLabel!,
                style: const TextStyle(fontSize: 11.5, color: _C.faint),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          order.shop,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _C.ink,
          ),
        ),
        if ((detail.moneyStatusLabel ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Cash: ${detail.moneyStatusLabel}',
              style: const TextStyle(fontSize: 11.5, color: _C.muted),
            ),
          ),
        const Divider(height: 22, color: _C.border),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                detail.paymentLabel.isEmpty
                    ? 'Cash on delivery'
                    : detail.paymentLabel,
                style: const TextStyle(fontSize: 13, color: _C.body),
              ),
            ),
            Text(
              order.codAmount,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _C.green,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Items ${order.total} + shipping ${order.shippingFee}',
          style: const TextStyle(fontSize: 11, color: _C.faint),
        ),
      ],
    );
  }

  Widget _statusBadge(String status, String label) {
    late final Color bg;
    late final Color fg;
    if (status == 'cancelled' || status == 'delivery_failed') {
      bg = _C.dangerSoft;
      fg = _C.danger;
    } else if (status == 'returned') {
      bg = const Color(0xFFF3EEF4);
      fg = const Color(0xFF6D5D71);
    } else if (status == 'delivered' || status == 'completed') {
      bg = _C.greenSoft;
      fg = _C.green;
    } else if (status == 'placed') {
      bg = _C.warningSoft;
      fg = _C.warning;
    } else {
      bg = const Color(0xFFF5ECF6);
      fg = _C.plumMid;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _terminalProgress(ApiOrderDetail detail) {
    final label = detail.progress.statusLabel.toLowerCase();
    return _card(
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'This order is '),
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _C.ink,
                ),
              ),
              TextSpan(
                text: detail.order.status == 'cancelled'
                    ? '. Reserved stock was returned to the seller.'
                    : '.',
              ),
            ],
          ),
          style: const TextStyle(fontSize: 13, color: _C.body, height: 1.4),
        ),
      ],
    );
  }

  Widget _progressCard(ApiOrderDetail detail) {
    final steps = detail.progress.steps;
    return _card(
      title: 'Progress',
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
      children: [
        SizedBox(
          height: 64,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  SizedBox(
                    width: 78,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 26,
                          child: Row(
                            children: [
                              Expanded(
                                child: i == 0
                                    ? const SizedBox()
                                    : Container(
                                        height: 2,
                                        color: steps[i].done
                                            ? _C.accent
                                            : const Color(0xFFEADFEC),
                                      ),
                              ),
                              _stepDot(steps[i]),
                              Expanded(
                                child: i == steps.length - 1
                                    ? const SizedBox()
                                    : Container(
                                        height: 2,
                                        color: steps[i + 1].done
                                            ? _C.accent
                                            : const Color(0xFFEADFEC),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: steps[i].done
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: steps[i].done ? _C.ink : _C.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepDot(ApiOrderStep step) {
    if (step.current) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _C.accent,
          border: Border.all(color: const Color(0xFFE9D8EC), width: 3),
        ),
        child: step.done
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : null,
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: step.done ? _C.accent : const Color(0xFFEADFEC),
      ),
      child: step.done
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }

  Widget _itemsCard(ApiOrderDetail detail) {
    final completed = detail.order.status == 'completed';
    return _card(
      title: 'Items',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      children: [
        for (var i = 0; i < detail.items.length; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (i > 0) const Divider(height: 1, color: _C.headBg),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _itemRow(detail.items[i], completed),
              ),
            ],
          ),
      ],
    );
  }

  Widget _itemRow(ApiOrderItem item, bool completed) {
    final options = [
      if ((item.color ?? '').isNotEmpty) item.color!,
      if ((item.size ?? '').isNotEmpty) item.size!,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.image,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: _C.headBg,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 20,
                    color: _C.faint,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: item.productId > 0 ? () => _openProduct(item) : null,
                    child: Text(
                      item.name.isEmpty
                          ? 'Product no longer available'
                          : item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: item.name.isEmpty ? _C.muted : _C.ink,
                      ),
                    ),
                  ),
                  if (options.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        options,
                        style: const TextStyle(fontSize: 11.5, color: _C.faint),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${item.price} each · Qty ${item.quantity}',
                      style: const TextStyle(fontSize: 11.5, color: _C.muted),
                    ),
                  ),
                  InkWell(
                    onTap: _working ? null : _openChat,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Ask about this item',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _C.accent,
                          decoration: TextDecoration.underline,
                          decorationColor: _C.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.lineTotal.isEmpty ? item.price : item.lineTotal,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _C.plumMid,
              ),
            ),
          ],
        ),
        if (completed) ...[
          const SizedBox(height: 8),
          if (item.review != null)
            _reviewBlock(item.review!)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _review(item),
                icon: const Icon(Icons.star_border_rounded, size: 16),
                label: const Text('Rate this product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.plumMid,
                  side: const BorderSide(color: _C.accent),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _reviewBlock(ApiOrderReview review) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.headBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your review',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _C.plum,
                ),
              ),
              const SizedBox(width: 6),
              _Stars(rating: review.rating),
            ],
          ),
          if (review.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                review.comment,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: _C.body,
                ),
              ),
            ),
          if (review.hidden)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'This review is hidden while it is being reviewed.',
                style: TextStyle(fontSize: 11.5, color: _C.muted),
              ),
            ),
          if ((review.reply ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: _C.accent, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seller reply',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.plum,
                    ),
                  ),
                  Text(
                    review.reply!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF5B4A60),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _updatesCard(ApiOrderDetail detail) {
    return _card(
      title: 'Order updates',
      children: [
        if (detail.timeline.isEmpty)
          const Text(
            'No updates yet. Updates appear here when the seller or logistics '
            'changes the order.',
            style: TextStyle(fontSize: 12.5, color: _C.muted, height: 1.4),
          )
        else
          for (var i = 0; i < detail.timeline.length; i++)
            _timelineRow(
              detail.timeline[i],
              isFirst: i == 0,
              isLast: i == detail.timeline.length - 1,
            ),
      ],
    );
  }

  Widget _timelineRow(
    ApiOrderEvent event, {
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                if (isFirst)
                  Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.only(top: 5),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE9D8EC),
                    ),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.accent,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD8C4DC),
                    ),
                  ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 3),
                      color: const Color(0xFFEADFEC),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.ink,
                    ),
                  ),
                  if ((event.atLabel ?? '').isNotEmpty)
                    Text(
                      event.atLabel!,
                      style: const TextStyle(fontSize: 11.5, color: _C.faint),
                    ),
                  if ((event.note ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        event.note!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xFF5B4A60),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ApiOrderDetail detail) {
    final order = detail.order;
    final voucher = detail.voucherDiscount ?? '';
    final hasVoucher =
        voucher.isNotEmpty &&
        voucher != '₱0' &&
        voucher != '₱0.00' &&
        (detail.voucherCode ?? '').isNotEmpty;

    return _card(
      title: 'Order summary',
      children: [
        _kv(
          'Items',
          detail.itemsTotal.isEmpty ? order.total : detail.itemsTotal,
        ),
        if (hasVoucher)
          _kv('Voucher ${detail.voucherCode}', '−$voucher', color: _C.green),
        _kv('Shipping fee', order.shippingFee),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 9),
          child: Divider(height: 1, color: _C.border),
        ),
        _kv('Total', order.total, big: true),
        const SizedBox(height: 2),
        _kv(
          'Payment',
          detail.paymentLabel.isEmpty
              ? 'Cash on delivery'
              : detail.paymentLabel,
        ),
        if (!const [
          'delivered',
          'completed',
          'cancelled',
          'returned',
        ].contains(order.status))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _C.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Please have ${order.codAmount} ready in cash for the rider.',
              style: const TextStyle(fontSize: 11.5, color: _C.plumMid),
            ),
          ),
      ],
    );
  }

  Widget _kv(String label, String value, {Color? color, bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: big ? 13.5 : 12.5,
                fontWeight: big ? FontWeight.w600 : FontWeight.w400,
                color: big ? _C.ink : _C.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 18 : 12.5,
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              color: color ?? (big ? _C.plumMid : _C.ink),
              height: big ? 1.15 : 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressCard(ApiOrderDetail detail) {
    return _card(
      title: 'Delivery address',
      children: [
        Text(
          (detail.shippingAddress ?? '').isEmpty
              ? '—'
              : detail.shippingAddress!,
          style: const TextStyle(fontSize: 12.5, height: 1.5, color: _C.body),
        ),
      ],
    );
  }

  Widget _noteCard(String note) {
    return _card(
      title: 'Message to seller',
      children: [
        Text(
          note,
          style: const TextStyle(fontSize: 12.5, height: 1.5, color: _C.body),
        ),
      ],
    );
  }

  Widget _soldByCard(ApiOrderSeller seller) {
    return _card(
      title: 'Sold by',
      children: [
        Text(
          seller.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _C.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openChat,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.plumMid,
                  side: const BorderSide(color: _C.accent),
                  minimumSize: const Size(0, 38),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Chat with seller'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _openShop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.body,
                  side: const BorderSide(color: Color(0xFFE5DCE7)),
                  minimumSize: const Size(0, 38),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View shop'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _trackingCard(ApiOrderTracking tracking) {
    final noAttemptsLeft =
        tracking.maxAttempts > 0 && tracking.attempts >= tracking.maxAttempts;
    return _card(
      title: 'Shipment tracking',
      children: [
        _trackingField('Vendo reference', tracking.number, selectable: true),
        if ((tracking.carrier ?? '').isNotEmpty)
          _trackingField('Carrier', tracking.carrier!),
        if ((tracking.carrierTracking ?? '').isNotEmpty)
          _trackingField(
            'Carrier tracking',
            tracking.carrierTracking!,
            selectable: true,
          ),
        if (tracking.hasDeliveryProof)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery proof',
                  style: TextStyle(fontSize: 11.5, color: _C.faint),
                ),
                GestureDetector(
                  onTap: _showDeliveryProof,
                  child: const Text(
                    'View delivery photo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _C.plumMid,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _trackingField(
          'Estimated delivery',
          tracking.estimatedLabel ?? 'Not yet scheduled',
        ),
        if (tracking.attempts > 0) ...[
          _trackingField(
            'Delivery attempts',
            tracking.maxAttempts > 0
                ? '${tracking.attempts} of ${tracking.maxAttempts}'
                : '${tracking.attempts}',
          ),
          if (noAttemptsLeft)
            const Padding(
              padding: EdgeInsets.only(left: 2, top: 1),
              child: Text(
                'No attempts left.',
                style: TextStyle(fontSize: 11.5, color: _C.danger),
              ),
            )
          else if ((tracking.nextAttemptLabel ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 1),
              child: Text(
                'Next attempt ${tracking.nextAttemptLabel}.',
                style: const TextStyle(fontSize: 11.5, color: _C.faint),
              ),
            ),
        ],
      ],
    );
  }

  /// The Seller's photo of the packed parcel, like the web order page's card.
  /// The file is private, so the Buyer's token travels with the image request.
  Widget _packedPhotoCard() {
    final headers = _pickupPhotoHeaders ??= BuyerApi.instance.mediaHeaders();
    return _card(
      title: 'Photo of your packed item',
      children: [
        FutureBuilder<Map<String, String>>(
          future: headers,
          builder: (context, snapshot) {
            final authHeaders = snapshot.data;
            if (authHeaders == null) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: snapshot.hasError
                      ? const Text(
                          'The packed-item photo could not be loaded.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: _C.muted),
                        )
                      : const CircularProgressIndicator(),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    BuyerApi.instance.orderPickupPhotoUrl(widget.orderId),
                    headers: authHeaders,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 240,
                      alignment: Alignment.center,
                      color: _C.soft,
                      child: const Text(
                        'The packed-item photo could not be loaded.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: _C.muted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The seller took this before handing it to the rider.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: _C.muted,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _trackingField(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: _C.faint)),
          selectable
              ? SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: _C.ink,
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: _C.ink,
                  ),
                ),
        ],
      ),
    );
  }

  List<Widget> _returnSection(ApiOrderDetail detail) {
    final request = detail.returnRequest;
    if (request != null) {
      return [
        _card(
          title: 'Return request',
          children: [
            Text(
              request.statusLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Reason: ${request.reasonLabel}',
              style: const TextStyle(fontSize: 12.5, color: _C.body),
            ),
            if (request.approved) ...[
              const SizedBox(height: 4),
              Text(
                'Refund ${request.refund ?? ''} — the seller approved the return.',
                style: const TextStyle(fontSize: 12.5, color: _C.green),
              ),
              if ((request.returnStatusLabel ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Parcel return: ${request.returnStatusLabel}'
                    '${(request.pickedUpAtLabel ?? '').isNotEmpty ? ' · collected ${request.pickedUpAtLabel}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: _C.faint),
                  ),
                ),
            ] else if (request.rejected) ...[
              const SizedBox(height: 4),
              Text(
                "Seller's reason: ${request.decisionNote ?? ''}",
                style: const TextStyle(fontSize: 12.5, color: _C.danger),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Sent ${request.timeAgo ?? 'recently'}. The seller will review it.',
                style: const TextStyle(fontSize: 12, color: _C.faint),
              ),
            ],
          ],
        ),
      ];
    }

    if (detail.canRequestReturn) {
      final closes = detail.returnWindowClosesLabel;
      final days = detail.returnDaysLeft;
      final countdown = days == null
          ? ''
          : days == 0
          ? ' · last day'
          : ' · $days day${days == 1 ? '' : 's'} left';
      return [
        _card(
          children: [
            const Text(
              'Something wrong with this order? You can ask the seller to take it back.',
              style: TextStyle(fontSize: 12.5, color: _C.body, height: 1.4),
            ),
            if (closes != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'Return window closes $closes$countdown.',
                  style: const TextStyle(fontSize: 11.5, color: _C.faint),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: _working ? null : _requestReturn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.plumMid,
                  side: const BorderSide(color: _C.accent),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Request a return'),
              ),
            ),
          ],
        ),
      ];
    }

    if (detail.returnWindowClosesLabel != null &&
        const ['delivered', 'completed'].contains(detail.order.status)) {
      return [
        _card(
          children: [
            Text(
              'The return window for this order closed on '
              '${detail.returnWindowClosesLabel}.',
              style: const TextStyle(fontSize: 12.5, color: _C.body),
            ),
          ],
        ),
      ];
    }

    return const [];
  }

  Widget _confirmReceivedCard() {
    return _card(
      children: [
        const Text(
          'Your order was delivered. Confirm that you received it to finish '
          'the order and rate your items.',
          style: TextStyle(fontSize: 12.5, color: _C.body, height: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _C.green,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _working ? null : _completeOrder,
            child: const Text('Confirm order received'),
          ),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: _working ? null : _cancelOrder,
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.danger,
            side: const BorderSide(color: Color(0xFFE5C9D1)),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Cancel order'),
        ),
      ),
    );
  }

  Widget _cancelLockedNotes() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEADFEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: _C.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text:
                        'This order can no longer be cancelled because the seller '
                        'has started preparing it. If something is wrong, ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: _openChat,
                      child: const Text(
                        'chat with the seller',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: _C.plumMid,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF5B4A60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 14,
          color: _C.star,
        );
      }),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarPicker({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // A default IconButton asks for 48dp, so five of them need 240dp while the
    // review AlertDialog leaves about 232dp of content width on a 360dp phone:
    // the fifth star overflowed by the 8dp difference. Giving each button an
    // equal share of the row keeps all five stars inside the dialog on any
    // width, and lets the dialog's intrinsic width (five 48dp buttons) decide
    // how wide it opens. LayoutBuilder and FittedBox are not options here
    // because AlertDialog measures its content through IntrinsicWidth, which
    // neither of them supports.
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        return Expanded(
          child: IconButton(
            onPressed: () => onChanged(value),
            padding: EdgeInsets.zero,
            icon: Icon(
              value <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: _C.star,
              size: 30,
            ),
          ),
        );
      }),
    );
  }
}
