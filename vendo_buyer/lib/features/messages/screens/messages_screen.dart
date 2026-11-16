import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/messages/screens/seller_chat_screen.dart';
import 'package:vendo_buyer/features/messages/screens/support_chat_screen.dart';
import 'package:vendo_buyer/features/orders/screens/orders_screen.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// The Buyer's Messages inbox: shop chats and Vendo Support, the same records
/// the web Messages page reads. Polls like the web list so new replies appear.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  ApiSellerChats? _chats;
  ApiSupportInbox? _inbox;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _starting;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        BuyerApi.instance.sellerChats(),
        BuyerApi.instance.supportInbox(),
      ]);
      if (!mounted) return;
      setState(() {
        _chats = results[0] as ApiSellerChats;
        _inbox = results[1] as ApiSupportInbox;
        _loading = false;
        _error = null;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error =
              'Could not reach Vendo. Check your connection and try again.';
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'Messages',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your messages',
              text: _error!,
              actionLabel: 'Try again',
              onAction: () => _load(),
            )
          : RefreshIndicator(
              color: ProfileColors.header,
              onRefresh: () => _load(),
              child: _content(),
            ),
    );
  }

  Widget _content() {
    final chats = _chats?.items ?? const <ApiSellerChat>[];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'Chat with sellers about your orders, or reach Vendo Support.',
          style: TextStyle(
            color: ProfileColors.muted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _sellerChatsCard(chats),
        const SizedBox(height: 14),
        _supportCard(),
      ],
    );
  }

  // ── Seller chats ─────────────────────────────────────────────────────────
  Widget _sellerChatsCard(List<ApiSellerChat> chats) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ProfileColors.white,
        borderRadius: BorderRadius.circular(profileRadius),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller chats',
                  style: TextStyle(
                    color: ProfileColors.header,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Questions about an order stay with the seller of that order.',
                  style: TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ProfileColors.border),
          if (chats.isEmpty)
            _sellerEmpty()
          else
            for (int i = 0; i < chats.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: ProfileColors.border),
              _sellerChatRow(chats[i]),
            ],
        ],
      ),
    );
  }

  Widget _sellerEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: ProfileColors.soft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF805487),
              size: 23,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No seller chats yet',
            style: TextStyle(
              color: ProfileColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Open an order and choose "Ask about item", or visit a shop and tap Chat, to start one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ProfileColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ProfileColors.purple,
                side: const BorderSide(color: Color(0xFF805487)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Go to My Orders',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerChatRow(ApiSellerChat chat) {
    final unread = chat.unread > 0;
    return InkWell(
      onTap: () => _openSellerChat(chat),
      child: Container(
        padding: EdgeInsets.fromLTRB(unread ? 13 : 16, 12, 14, 12),
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFFBF6FC) : ProfileColors.white,
          border: unread
              ? const Border(
                  left: BorderSide(color: Color(0xFF805487), width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            _avatar(chat.sellerAvatar, chat.initial),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread
                                ? ProfileColors.ink
                                : const Color(0xFF3D2A42),
                            fontSize: 13,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if ((chat.time ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          chat.time!,
                          style: const TextStyle(
                            color: ProfileColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread
                          ? const Color(0xFF3D2A42)
                          : ProfileColors.muted,
                      fontSize: 12,
                      fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEF4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      chat.orderNumber != null
                          ? 'Order #${chat.orderNumber}'
                          : 'Shop inquiry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6D5D71),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ProfileColors.header,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  chat.unread > 99 ? '99+' : '${chat.unread}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Vendo Support ────────────────────────────────────────────────────────
  Widget _supportCard() {
    final conversation = _inbox?.conversation;
    final reasons = _inbox?.reasons ?? const <ApiSupportReason>[];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ProfileColors.white,
        borderRadius: BorderRadius.circular(profileRadius),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: ProfileColors.header,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vendo Support',
                        style: TextStyle(
                          color: ProfileColors.header,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation == null
                            ? 'Pick a topic to start a conversation with our team.'
                            : conversation.isOpen
                            ? 'Our team replies in this conversation.'
                            : 'Your last conversation has ended. Start a new one any time.',
                        style: const TextStyle(
                          color: ProfileColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ProfileColors.border),
          if (conversation != null && conversation.isOpen)
            _openSupportRow(conversation)
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (int i = 0; i < reasons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _reasonRow(reasons[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _openSupportRow(ApiSupportConversation conversation) {
    return InkWell(
      onTap: () => _openSupport(conversation.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: ProfileColors.soft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF805487),
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Continue conversation',
                    style: TextStyle(
                      color: ProfileColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.lastPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: ProfileColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonRow(ApiSupportReason reason) {
    final busy = _starting == reason.name;
    return InkWell(
      onTap: _starting == null ? () => _startSupport(reason.name) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: ProfileColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ProfileColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: ProfileColors.soft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _reasonIcon(reason.name),
                color: const Color(0xFF52245B),
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.name,
                    style: const TextStyle(
                      color: ProfileColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason.description,
                    style: const TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ProfileColors.header,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: ProfileColors.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  IconData _reasonIcon(String name) => switch (name) {
    'General Inquiry' => Icons.help_outline_rounded,
    'Raise a Concern' => Icons.warning_amber_rounded,
    _ => Icons.more_horiz_rounded,
  };

  Widget _avatar(String? url, String initial, {double size = 44}) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFF805487),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return ClipOval(
      child: (url == null || url.isEmpty)
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  Future<void> _openSellerChat(ApiSellerChat chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerChatScreen(
          sellerId: chat.sellerId,
          sellerName: chat.sellerName,
          orderId: chat.orderId,
        ),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _openSupport(int conversationId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(conversationId: conversationId),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _startSupport(String reason) async {
    if (_starting != null) return;
    setState(() => _starting = reason);
    try {
      final conversation = await BuyerApi.instance.startSupportChat(reason);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(conversationId: conversation.id),
        ),
      );
      if (mounted) _load(silent: true);
    } on BuyerApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not start the conversation. Check your connection.');
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
