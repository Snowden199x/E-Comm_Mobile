import 'package:flutter/material.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _resetToken;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on RiderApiException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('Could not reach Vendo. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _sendCode() => _run(() async {
    await RiderApi.instance.sendPasswordResetCode(_email.text);
    if (mounted) {
      _message(
        'If a Rider account exists for that email, a reset code will be sent.',
      );
    }
  });

  Future<void> _verifyCode() => _run(() async {
    final token = await RiderApi.instance.verifyPasswordResetCode(
      _email.text,
      _code.text,
    );
    if (mounted) setState(() => _resetToken = token);
  });

  Future<void> _resetPassword() => _run(() async {
    if (_password.text.length < 8 || _password.text != _confirmation.text) {
      _message('Use at least 8 characters and enter the same password twice.');
      return;
    }
    await RiderApi.instance.resetPassword(
      _email.text,
      _resetToken!,
      _password.text,
      _confirmation.text,
    );
    if (!mounted) return;
    _message('Password reset. You can now sign in.');
    Navigator.pop(context);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reset password'),
      backgroundColor: AppColors.headerBg,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Recover your Rider account',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A1440),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will email a one-time code to verify your account before you choose a new password.',
          ),
          const SizedBox(height: 22),
          _input(
            _email,
            'Email address',
            keyboard: TextInputType.emailAddress,
            readOnly: _resetToken != null,
          ),
          if (_resetToken == null) ...[
            const SizedBox(height: 12),
            _input(_code, '6-digit code', keyboard: TextInputType.number),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _sendCode,
              child: const Text('Send reset code'),
            ),
            FilledButton(
              onPressed: _busy ? null : _verifyCode,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B1F52),
              ),
              child: Text(_busy ? 'Please wait…' : 'Verify code'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _input(_password, 'New password', obscure: true),
            const SizedBox(height: 12),
            _input(_confirmation, 'Confirm new password', obscure: true),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _resetPassword,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B1F52),
              ),
              child: Text(_busy ? 'Please wait…' : 'Save new password'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _input(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool readOnly = false,
    TextInputType? keyboard,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    readOnly: readOnly,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}
