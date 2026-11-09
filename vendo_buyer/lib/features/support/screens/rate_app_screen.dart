import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Rate the App. The rating is kept on this device with the signed-in session;
/// it is cleared when the Buyer signs out. Order and account help lives in
/// Help & FAQ, which is API-backed.
class RateAppScreen extends StatefulWidget {
  const RateAppScreen({super.key});

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
  final _comment = TextEditingController();

  int _rating = 0;
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rating = await BuyerApi.instance.appRating();
    final comment = await BuyerApi.instance.appRatingComment();
    if (!mounted) return;
    setState(() {
      _rating = rating ?? 0;
      _comment.text = comment ?? '';
      _saved = rating != null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap a star to rate the app first.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await BuyerApi.instance.saveAppRating(_rating, _comment.text);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for rating Vendo.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your rating. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'Rate the App',
      child: _loading
          ? const ProfileLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProfileCard(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: ProfileColors.soft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: ProfileColors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'How is Vendo so far?',
                        style: TextStyle(
                          color: ProfileColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your rating helps us make the Buyer app better.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProfileColors.muted,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ProfileStars(
                        rating: _rating,
                        size: 38,
                        onChanged: (value) =>
                            setState(() => _rating = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _rating == 0
                            ? 'Tap a star'
                            : '$_rating out of 5',
                        style: const TextStyle(
                          color: ProfileColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: ProfileColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ProfileColors.border),
                        ),
                        child: TextField(
                          controller: _comment,
                          maxLines: 4,
                          maxLength: 500,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ProfileColors.ink,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Anything you want us to know? (optional)',
                            hintStyle: TextStyle(
                              color: ProfileColors.muted,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(14),
                            counterStyle: TextStyle(
                              color: ProfileColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ProfilePrimaryButton(
                        label: _saved ? 'Update rating' : 'Submit rating',
                        loading: _saving,
                        onPressed: _save,
                      ),
                      if (_saved) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Your rating is saved on this device.',
                          style: TextStyle(
                            color: ProfileColors.green,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const ProfileCard(
                  child: Text(
                    'This is a quick in-app rating, not a store review. For help with an order or your account, open Help & FAQ.',
                    style: TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 11.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
