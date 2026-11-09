import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Help and FAQ from `GET /api/v1/buyer/help`. The answers describe the same
/// order, delivery, voucher and account rules the web buyer pages follow.
class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  ApiFaqPage? _page;
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
      final page = await BuyerApi.instance.help();
      if (!mounted) return;
      setState(() {
        _page = page;
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

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$email copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'Help & FAQ',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load Help & FAQ',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : _content(),
    );
  }

  Widget _content() {
    final page = _page!;

    return RefreshIndicator(
      color: ProfileColors.header,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ProfileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How can we help?',
                  style: TextStyle(
                    color: ProfileColors.header,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  page.intro,
                  style: const TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          for (final group in page.groups) ...[
            const SizedBox(height: 20),
            ProfileSectionTitle(group.title),
            const SizedBox(height: 10),
            ProfileCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < group.items.length; i++) ...[
                    _FaqTile(item: group.items[i]),
                    if (i < group.items.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: ProfileColors.border,
                      ),
                  ],
                ],
              ),
            ),
          ],
          if (page.contactEmail != null) ...[
            const SizedBox(height: 20),
            ProfileSectionTitle('Contact Support'),
            const SizedBox(height: 10),
            ProfileCard(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: ProfileColors.soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: ProfileColors.header,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email Vendo Support',
                          style: TextStyle(
                            color: ProfileColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          page.contactEmail!,
                          style: const TextStyle(
                            color: ProfileColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _copyEmail(page.contactEmail!),
                    child: const Text(
                      'Copy',
                      style: TextStyle(
                        color: ProfileColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final ApiFaqItem item;

  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      iconColor: ProfileColors.header,
      collapsedIconColor: ProfileColors.muted,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        item.question,
        style: const TextStyle(
          color: ProfileColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.answer,
            style: const TextStyle(
              color: ProfileColors.muted,
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
