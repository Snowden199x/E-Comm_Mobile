import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/orders/screens/order_detail_screen.dart';
import 'package:vendo_buyer/features/seller_page/screens/api_seller_screen.dart';

// Same colours as the web chat page (shared/marketplace-thread.blade.php).
class _C {
  static const bg = Color(0xFFF7F3F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B1730);
  static const plum = Color(0xFF402143);
  static const plumMid = Color(0xFF52245B);
  static const plumSoft = Color(0xFF805487);
  static const pillBg = Color(0xFFF5ECF6);
  static const muted = Color(0xFF6F5F73);
  static const border = Color(0xFFEEE6EF);
  static const mutedGray = Color(0xFF9A8A9D);
  static const bubbleMine = Color(0xFF402143);
  static const bubbleOther = Color(0xFFFFFFFF);
  static const systemBg = Color(0xFFF2EDF3);
  static const fieldBg = Color(0xFFFAF7FB);

  // System message card (cream / gold)
  static const sysCardBg = Color(0xFFFDF8E6);
  static const sysCardBorder = Color(0xFFEBDDA8);
  static const sysMeta = Color(0xFFB5A369);
  static const sysText = Color(0xFF8A6A1C);
}

/// Chat with a shop, on the same threads the web chat page uses.
///
/// A shop chat has no order. When the Buyer already bought from the shop, the
/// web opens their newest order's chat instead, and this screen follows that
/// redirect. Sharing an order is only possible from that order's chat, so
/// sharing from the shop chat moves here into the order's chat, like the web.
class SellerChatScreen extends StatefulWidget {
  final int sellerId;
  final String? sellerName;
  final int? orderId;

  const SellerChatScreen({
    super.key,
    required this.sellerId,
    this.sellerName,
    this.orderId,
  });

  @override
  State<SellerChatScreen> createState() => _SellerChatScreenState();
}

class _SellerChatScreenState extends State<SellerChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _bodyCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  ApiChatSeller? _seller;
  ApiChatOrder? _order;
  List<ApiChatMessage> _messages = const [];
  List<ApiChatOrder> _shareOrders = const [];

  int? _orderId;
  Map<String, String>? _mediaHeaders;

  bool _loading = true;
  bool _sending = false;
  String? _error;

  Timer? _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orderId = widget.orderId;
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _bodyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pollNow();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final headers = _mediaHeaders ?? await BuyerApi.instance.mediaHeaders();
      final thread = await BuyerApi.instance.chatThread(
        sellerId: _orderId == null ? widget.sellerId : null,
        orderId: _orderId,
      );
      if (!mounted) return;

      // The web sends a Buyer with past orders straight into that order's chat.
      if (thread.redirectOrderId != null && _orderId == null) {
        _orderId = thread.redirectOrderId;
        await _load(silent: silent);
        return;
      }

      setState(() {
        _mediaHeaders = headers;
        _seller = thread.seller ?? _seller;
        _order = thread.order;
        _messages = thread.messages;
        _shareOrders = thread.shareOrders;
        _loading = false;
        _error = null;
      });
      if (!silent) _startPoll();
      _scrollToBottom();
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _error = 'Could not reach Vendo. Check your connection and retry.';
        }
        _loading = false;
      });
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollNow());
  }

  Future<void> _pollNow() async {
    if (_polling || _loading || _sending) return;
    _polling = true;
    try {
      final fresh = await BuyerApi.instance.chatNewMessages(
        sellerId: _orderId == null ? widget.sellerId : null,
        orderId: _orderId,
        after: _messages.isEmpty ? 0 : _messages.last.id,
      );
      if (!mounted || fresh.isEmpty) return;
      setState(() {
        final seen = _messages.map((message) => message.id).toSet();
        _messages = [
          ..._messages,
          ...fresh.where((message) => !seen.contains(message.id)),
        ];
      });
      _scrollToBottom(animate: true);
    } catch (_) {
      // A missed poll is not worth an error banner; the next one retries.
    } finally {
      _polling = false;
    }
  }

  Future<void> _send({String? attachmentPath}) async {
    if (_sending) return;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty && attachmentPath == null) return;
    setState(() => _sending = true);
    try {
      await BuyerApi.instance.sendChatMessage(
        sellerId: _orderId == null ? widget.sellerId : null,
        orderId: _orderId,
        body: body,
        attachmentPath: attachmentPath,
      );
      if (!mounted) return;
      _bodyCtrl.clear();
      await _load(silent: true);
      _scrollToBottom(animate: true);
    } on BuyerApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Message could not be sent. Check your connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_sending) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (photo == null) return;
      await _send(attachmentPath: photo.path);
    } catch (_) {
      _toast('Could not open your photos.');
    }
  }

  Future<void> _shareOrder(ApiChatOrder order) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      if (_orderId == null) {
        // Sharing moves the conversation to that order's own chat, as on the web.
        await BuyerApi.instance.sendChatMessage(
          orderId: order.id,
          sharedOrderId: order.id,
        );
        if (!mounted) return;
        setState(() {
          _orderId = order.id;
          _messages = const [];
          _order = null;
        });
        await _load();
      } else {
        await BuyerApi.instance.sendChatMessage(
          orderId: _orderId,
          sharedOrderId: order.id,
        );
        await _load(silent: true);
      }
      _scrollToBottom(animate: true);
    } on BuyerApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('The order could not be shared. Check your connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openShareSheet() async {
    if (_shareOrders.isEmpty) return;
    final chosen = await showModalBottomSheet<ApiChatOrder>(
      context: context,
      backgroundColor: _C.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Share an order',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _C.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'The seller sees this order in the chat, so you can ask about it.',
                style: TextStyle(fontSize: 12, color: _C.muted, height: 1.35),
              ),
              const SizedBox(height: 10),
              ..._shareOrders.map(
                (order) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(sheetContext).pop(order),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: _C.plumMid,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            order.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _C.ink,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _C.mutedGray,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await _shareOrder(chosen);
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _C.plum,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApiSellerScreen(sellerId: widget.sellerId),
      ),
    );
  }

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                headers: _mediaHeaders,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              if (_order != null) _orderStrip(_order!),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _C.plum),
                      )
                    : _error != null
                    ? _errorState()
                    : _thread(),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final shopName = (_seller?.name ?? widget.sellerName ?? '').trim();
    final displayName = shopName.isEmpty ? 'Shop' : shopName;
    final subtitle = _order == null
        ? 'Seller · View profile'
        : 'Order #${_order!.number} · Seller · View profile';

    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _C.plum,
            ),
            tooltip: 'Back',
          ),
          _avatar(
            url: _seller?.avatar,
            initial: _seller?.initial ?? displayName.substring(0, 1),
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _openShop,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _C.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _C.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _openShop,
            icon: const Icon(
              Icons.storefront_outlined,
              size: 20,
              color: _C.plumSoft,
            ),
            tooltip: 'View shop',
          ),
        ],
      ),
    );
  }

  Widget _orderStrip(ApiChatOrder order) {
    return Container(
      width: double.infinity,
      color: _C.pillBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 11.5,
            color: _C.plumMid,
            height: 1.35,
          ),
          children: [
            const TextSpan(text: 'You are discussing order '),
            TextSpan(
              text: '#${order.number}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(
              text: '. Messages for this order stay in this conversation.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _thread() {
    if (_messages.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: _C.pillBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 24,
                color: _C.plumSoft,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Send a message or share an order with the seller.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _C.muted, height: 1.45),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      itemCount: _messages.length,
      itemBuilder: (_, index) => _messageRow(_messages[index]),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 34, color: _C.plumSoft),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not open this chat.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _C.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _load(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.plumMid,
                side: const BorderSide(color: _C.plumSoft),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageRow(ApiChatMessage message) {
    // ── System message: cream card with a small meta line on top ──────────
    if (message.system) {
      final meta = message.meta.trim();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
          decoration: BoxDecoration(
            color: _C.sysCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.sysCardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (meta.isNotEmpty) ...[
                Text(
                  meta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _C.sysMeta,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message.body ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _C.sysText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mine = message.mine;
    final bubble = _bubble(message);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            _avatar(url: message.avatar, initial: message.initial, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                  child: Text(
                    message.meta,
                    style: const TextStyle(fontSize: 10, color: _C.mutedGray),
                  ),
                ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ApiChatMessage message) {
    final mine = message.mine;
    final maxWidth = MediaQuery.of(context).size.width * 0.74;
    final hasBody = (message.body ?? '').trim().isNotEmpty;
    final attachment = message.attachmentUrl;
    final sharedOrder = message.sharedOrder;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (hasBody)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: mine ? _C.bubbleMine : _C.bubbleOther,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(mine ? 12 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 12),
                ),
                border: mine ? null : Border.all(color: _C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.item != null && message.item!.isNotEmpty) ...[
                    Text(
                      'About: ${message.item}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: mine ? const Color(0xFFE4CFE8) : _C.plumMid,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.body!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: mine ? Colors.white : _C.ink,
                    ),
                  ),
                ],
              ),
            ),
          if (attachment != null) ...[
            if (hasBody) const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openPhoto(attachment),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  attachment,
                  headers: _mediaHeaders,
                  width: 200,
                  height: 160,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 200,
                          height: 160,
                          color: _C.systemBg,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _C.plumSoft,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 160,
                    color: _C.systemBg,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: _C.plumSoft,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (sharedOrder != null) ...[
            if (hasBody) const SizedBox(height: 6),
            _sharedOrderCard(sharedOrder, system: false),
          ],
        ],
      ),
    );
  }

  Widget _sharedOrderCard(ApiChatSharedOrder order, {required bool system}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.orderId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                system ? 'Order update' : 'Order shared',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: _C.mutedGray,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        order.image!,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 38,
                          height: 38,
                          color: _C.systemBg,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: _C.mutedGray,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _C.systemBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: _C.mutedGray,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.ink,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.itemCount} item(s) · ${order.total}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (order.hasTracking) ...[
                const SizedBox(height: 6),
                Text(
                  order.trackingLabel,
                  style: const TextStyle(fontSize: 10.5, color: _C.muted),
                ),
              ],
              const SizedBox(height: 8),
              Container(height: 1, color: _C.border),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.number} · ${order.status}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: _C.muted,
                      ),
                    ),
                  ),
                  const Text(
                    'View order ↗',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _C.plumMid,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    final placeholder = _order == null
        ? 'Message the seller...'
        : 'Message the seller about this order...';

    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _bodyCtrl,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 13, color: _C.ink),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(fontSize: 13, color: _C.mutedGray),
                counterText: '',
                filled: true,
                fillColor: _C.fieldBg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.plumSoft),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  color: _C.plumMid,
                  tooltip: 'Attach photo',
                  visualDensity: VisualDensity.compact,
                ),
                if (_shareOrders.isNotEmpty)
                  IconButton(
                    onPressed: _sending ? null : _openShareSheet,
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    color: _C.plumMid,
                    tooltip: 'Share an order',
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: _sending ? null : () => _send(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _C.plum,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _C.plumSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send message',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar({
    required String? url,
    required String initial,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _C.plumMid,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null || url.trim().isEmpty
          ? Text(
              initial.isEmpty ? '?' : initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            )
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(
                initial.isEmpty ? '?' : initial,
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}
