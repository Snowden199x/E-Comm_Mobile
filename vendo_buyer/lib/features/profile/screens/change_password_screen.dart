import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Changes the password of the signed-in Buyer through
/// `PUT /api/v1/buyer/account/password`, the same rule the web account page uses.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  bool _updated = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _updated = false;
    });

    try {
      await BuyerApi.instance.changePassword(
        currentPassword: _current.text,
        password: _next.text,
        passwordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      setState(() {
        _updated = true;
        _current.clear();
        _next.clear();
        _confirm.clear();
      });
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'Change Password',
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change password',
                    style: TextStyle(
                      color: ProfileColors.header,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Use a password you do not use on other sites. It must be at least 8 characters.',
                    style: TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (_updated) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC9E5D3)),
                      ),
                      child: const Text(
                        'Password updated successfully.',
                        style: TextStyle(
                          color: ProfileColors.green,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ProfileTextField(
                    controller: _current,
                    label: 'Current password',
                    obscureText: !_showCurrent,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) => (value ?? '').isEmpty
                        ? 'Please enter your current password.'
                        : null,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      icon: Icon(
                        _showCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: ProfileColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProfileTextField(
                    controller: _next,
                    label: 'New password',
                    obscureText: !_showNext,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      final text = value ?? '';
                      if (text.isEmpty) return 'Please enter a new password.';
                      if (text.length < 8) {
                        return 'The new password must be at least 8 characters.';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showNext = !_showNext),
                      icon: Icon(
                        _showNext
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: ProfileColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProfileTextField(
                    controller: _confirm,
                    label: 'Confirm new password',
                    obscureText: !_showConfirm,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Confirm your new password.';
                      }
                      if (value != _next.text) {
                        return 'The password confirmation does not match.';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      icon: Icon(
                        _showConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: ProfileColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ProfilePrimaryButton(
                    label: 'Update password',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
