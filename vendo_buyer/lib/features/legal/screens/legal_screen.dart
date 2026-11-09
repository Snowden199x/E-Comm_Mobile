import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Terms and Privacy Policy from `GET /api/v1/buyer/legal/{page}`.
///
/// The server reads the same documents the public web pages serve, so the app
/// and vendo-ph.app always show the same wording.
class LegalScreen extends StatefulWidget {
  final String page;
  final String title;

  const LegalScreen({
    super.key,
    required this.page,
    required this.title,
  });

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  ApiContentPage? _content;
  bool _loading = true;
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
      final content = await BuyerApi.instance.legal(widget.page);
      if (!mounted) return;
      setState(() {
        _content = content;
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
        _error = 'Could not reach Vendo. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: widget.title,
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this page',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : _body(),
    );
  }

  Widget _body() {
    final page = _content!;

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          if (page.updatedLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                page.updatedLabel!,
                style: const TextStyle(
                  color: ProfileColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ),
          for (final block in page.blocks) _block(block),
          const SizedBox(height: 12),
          const Text(
            'Vendo processes personal data in accordance with the Philippine Data Privacy Act of 2012. Questions: vendoapp.official@gmail.com.',
            style: TextStyle(
              color: ProfileColors.muted,
              fontSize: 11,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(ApiContentBlock block) {
    if (block.type == 'heading') {
      final isTitle = block.level <= 1;
      return Padding(
        padding: EdgeInsets.only(top: isTitle ? 0 : 18, bottom: 6),
        child: Text(
          block.text,
          style: TextStyle(
            color: isTitle ? ProfileColors.header : ProfileColors.ink,
            fontSize: isTitle ? 19 : 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      );
    }

    if (block.type == 'bullet') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6, right: 8),
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: ProfileColors.orange,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                block.text,
                style: const TextStyle(
                  color: ProfileColors.ink,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        block.text,
        style: const TextStyle(
          color: ProfileColors.ink,
          fontSize: 12.5,
          height: 1.65,
        ),
      ),
    );
  }
}
