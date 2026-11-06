import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/widgets/profile_ui.dart';

/// Changes the signed-in Rider's password with the current password as proof.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _formError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    final currentError = current.isEmpty ? 'Enter your current password.' : null;
    final newError = next.length < 8
        ? 'Use at least 8 characters.'
        : (next == current ? 'Choose a password you have not used here.' : null);
    final confirmError = confirm.isEmpty
        ? 'Re-enter your new password.'
        : (confirm != next ? 'The passwords do not match.' : null);

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
      _formError = null;
    });

    if (currentError != null || newError != null || confirmError != null) {
      HapticFeedback.selectionClick();
      return;
    }

    setState(() => _saving = true);
    try {
      await RiderApi.instance.changePassword(
        currentPassword: current,
        password: next,
        confirmation: confirm,
      );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.of(context).pop();
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _formError =
              'Could not update your password. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ProfilePageScaffold(
      title: 'Change Password',
      subtitle: 'Keep your rider account secure',
      icon: Icons.lock_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileNote(
            text:
                'Confirm the password you use today, then choose a new one. This device stays signed in.',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 22),
          const ProfileSectionTitle(
            title: 'Account security',
            caption: 'Only you can change the password for this account',
          ),
          const SizedBox(height: 10),
          ProfileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PasswordField(
                  controller: _currentCtrl,
                  label: 'Current password',
                  hint: 'Enter your current password',
                  obscure: !_showCurrent,
                  onToggle: () =>
                      setState(() => _showCurrent = !_showCurrent),
                  errorText: _currentError,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _newCtrl,
                  label: 'New password',
                  hint: 'Create a new password',
                  obscure: !_showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                  errorText: _newError,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(
                    'At least 8 characters. Longer is stronger.',
                    style: TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _confirmCtrl,
                  label: 'Confirm new password',
                  hint: 'Re-enter your new password',
                  obscure: !_showConfirm,
                  onToggle: () =>
                      setState(() => _showConfirm = !_showConfirm),
                  errorText: _confirmError,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF1EE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0D3C9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: ProfileColors.brique,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formError!,
                      style: const TextStyle(
                        color: ProfileColors.brique,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfileColors.prune,
                disabledBackgroundColor: ProfileColors.prune,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: ProfileColors.lin,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Updating…',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Forgot your current password? Sign out and use Forgot password on the login screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ProfileColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }
}

OutlineInputBorder _border(Color color, [double width = 1.2]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.errorText,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ProfileColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          cursorColor: ProfileColors.prune,
          style: const TextStyle(color: ProfileColors.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: ProfileColors.muted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: ProfileColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: ProfileColors.muted,
                size: 20,
              ),
            ),
            border: _border(
              hasError ? ProfileColors.brique : ProfileColors.border,
            ),
            enabledBorder: _border(
              hasError ? ProfileColors.brique : ProfileColors.border,
            ),
            focusedBorder: _border(
              hasError ? ProfileColors.brique : ProfileColors.prune,
              1.6,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: ProfileColors.brique,
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}
