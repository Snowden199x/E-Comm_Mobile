import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';

// Same colours as the seller chat screen.
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
  static const danger = Color(0xFFB3261E);

  // System message card (cream / gold)
  static const sysCardBg = Color(0xFFFDF8E6);
  static const sysCardBorder = Color(0xFFEBDDA8);
  static const sysMeta = Color(0xFFB5A369);
  static const sysText = Color(0xFF8A6A1C);
}

/// Vendo Support chat, on the same Conversation rows the web Messages page
/// reads. Admin replies arrive through the short poll, and every message sent
/// here appears in the Admin inbox.
class SupportChatScreen extends StatefulWidget {
  final int conversationId;

  const SupportChatScreen({super.key, required this.conversationId});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _bodyCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  ApiSupportConversation? _conversation;
  bool _loading = true;
  bool _sending = false;
  bool _polling = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollNow());
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
      final conversation = await BuyerApi.instance.supportThread(
        widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _loading = false;
        _error = null;
      });
      if (!silent) _scrollToBottom();
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
          _error = 'Could not reach Vendo. Check your connection and retry.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pollNow() async {
    final current = _conversation;
    if (_polling ||
        _loading ||
        _sending ||
        current == null ||
        current.isClosed) {
      return;
    }
    _polling = true;
    try {
      final fresh = await BuyerApi.instance.supportThread(
        widget.conversationId,
      );
      if (!mounted) return;
      final changed =
          fresh.status != current.status ||
          fresh.messages.length != current.messages.length;
      if (changed) {
        setState(() => _conversation = fresh);
        _scrollToBottom(animate: true);
      }
    } catch (_) {
      // A missed poll retries on the next tick.
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
      await BuyerApi.instance.sendSupportMessage(
        widget.conversationId,
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

  Future<void> _confirmEnd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End this conversation?',
          style: TextStyle(
            color: _C.ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'You can start a new conversation with Vendo Support any time.',
          style: TextStyle(color: _C.muted, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Keep chatting',
              style: TextStyle(color: _C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'End',
              style: TextStyle(color: _C.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await BuyerApi.instance.closeSupportChat(widget.conversationId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BuyerApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not end the conversation. Check your connection.');
    }
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

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
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
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _C.plum),
                      )
                    : _error != null && _conversation == null
                    ? _errorState()
                    : _thread(),
              ),
              if (_conversation?.isClosed == true) _closedNotice(),
              if (_conversation?.isOpen == true) _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final conversation = _conversation;
    final subtitle = conversation?.isOpen == true
        ? 'Open conversation'
        : conversation?.isClosed == true
        ? 'Conversation ended'
        : 'Support';

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
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _C.plumMid,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.support_agent_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vendo Support',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _C.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: conversation?.isOpen == true
                              ? const Color(0xFF7ED6A0)
                              : _C.mutedGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
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
                ],
              ),
            ),
          ),
          if (conversation?.isOpen == true)
            TextButton(
              onPressed: _confirmEnd,
              style: TextButton.styleFrom(
                foregroundColor: _C.plumMid,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                'End',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thread() {
    final messages = _conversation?.messages ?? const <ApiSupportMessage>[];
    if (messages.isEmpty) {
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
            'Describe what you need and our team will reply here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _C.muted, height: 1.45),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      itemCount: messages.length,
      itemBuilder: (_, index) => _messageRow(messages[index]),
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
              _error ?? 'Could not open this conversation.',
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

  Widget _messageRow(ApiSupportMessage message) {
    // System message: cream card.
    if (message.isSystem) {
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
              if ((message.time ?? '').trim().isNotEmpty) ...[
                Text(
                  message.time!,
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
                message.body,
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

    final mine = message.isMine;

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
                if ((message.time ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 4,
                      left: 2,
                      right: 2,
                    ),
                    child: Text(
                      message.time!,
                      style: const TextStyle(fontSize: 10, color: _C.mutedGray),
                    ),
                  ),
                _bubble(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ApiSupportMessage message) {
    final mine = message.isMine;
    final maxWidth = MediaQuery.of(context).size.width * 0.74;
    final hasBody = message.body.trim().isNotEmpty;

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
              child: Text(
                message.body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: mine ? Colors.white : _C.ink,
                ),
              ),
            ),
          for (final attachment in message.attachments) ...[
            if (hasBody || attachment != message.attachments.first)
              const SizedBox(height: 6),
            _attachment(attachment, mine: mine),
          ],
        ],
      ),
    );
  }

  Widget _attachment(ApiSupportAttachment attachment, {required bool mine}) {
    if (attachment.isImage) {
      return GestureDetector(
        onTap: () => _openPhoto(attachment.url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            attachment.url,
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
      );
    }

    // Non-image file: small card, same look as the shared order card.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file_rounded, size: 16, color: _C.plumMid),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _C.plumMid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedNotice() {
    return Container(
      width: double.infinity,
      color: _C.pillBg,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: SafeArea(
        top: false,
        child: const Text(
          'This conversation has ended. Start a new one from Messages any time.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: _C.plumMid, height: 1.35),
        ),
      ),
    );
  }

  Widget _composer() {
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
                hintText: 'Message Vendo Support...',
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