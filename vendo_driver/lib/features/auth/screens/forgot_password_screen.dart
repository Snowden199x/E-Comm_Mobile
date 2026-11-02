import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';

/// Password recovery for the Transport Driver account.
///
/// The web emails a six-digit code, the code is exchanged for a short-lived
/// reset token, and the token is the only thing that can set a new password.
/// A driver who is still waiting for approval can use this too: recovery only
/// touches the account password, not the application decision.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  /// The address already typed on the sign-in screen, so the driver does not
  /// have to enter it again.
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  String? _resetToken;
  bool _codeSent = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  int get _step => _resetToken != null ? 3 : (_codeSent ? 2 : 1);

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail.trim();
  }

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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on DriverApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Cannot reach ${DriverApi.baseUrl}. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validEmail() {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter the email you applied with.');
      return false;
    }
    return true;
  }

  Future<void> _sendCode() async {
    if (!_validEmail()) return;
    await _run(() async {
      await DriverApi.instance.sendPasswordResetCode(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If a Transport Driver account exists for that email, a reset code will be sent.',
          ),
        ),
      );
    });
  }

  Future<void> _verifyCode() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the six-digit code from the email.');
      return;
    }
    await _run(() async {
      final token = await DriverApi.instance.verifyPasswordResetCode(
        _email.text,
        _code.text,
      );
      if (mounted) setState(() => _resetToken = token);
    });
  }

  Future<void> _savePassword() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Enter the same password twice.');
      return;
    }
    await _run(() async {
      await DriverApi.instance.resetPassword(
        _email.text,
        _resetToken!,
        _password.text,
        _confirmation.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: VColors.prune,
        body: Column(
          children: [
            _ResetHeader(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 22, 24, 24 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $_step of 3',
                        style: const TextStyle(
                          color: VColors.raisin,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        switch (_step) {
                          1 => 'Confirm your email',
                          2 => 'Enter the code',
                          _ => 'Choose a new password',
                        },
                        style: const TextStyle(
                          color: VColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        switch (_step) {
                          1 =>
                            'We will email a six-digit code to the address on your application.',
                          2 =>
                            'The code was sent to ${_email.text.trim()}. It expires in 10 minutes.',
                          _ =>
                            'Your new password must have at least 8 characters. Every signed-in device will be signed out.',
                        },
                        style: const TextStyle(
                          color: VColors.muted,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _Label('Email address'),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: _codeSent,
                        textInputAction: TextInputAction.next,
                        cursorColor: VColors.prune,
                        decoration: InputDecoration(
                          hintText: 'driver@vendoxpress.ph',
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: _codeSent
                              ? IconButton(
                                  tooltip: 'Use another email',
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _codeSent = false;
                                          _code.clear();
                                          _error = null;
                                        }),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: VColors.muted,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (_step == 2) ...[
                        const SizedBox(height: 16),
                        const _Label('Six-digit code'),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _verifyCode(),
                          cursorColor: VColors.prune,
                          decoration: const InputDecoration(
                            hintText: '123456',
                            counterText: '',
                            prefixIcon: Icon(Icons.pin_outlined, size: 20),
                          ),
                        ),
                      ],
                      if (_step == 3) ...[
                        const SizedBox(height: 16),
                        const _Label('New password'),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          cursorColor: VColors.prune,
                          decoration: InputDecoration(
                            hintText: 'At least 8 characters',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: VColors.muted,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _Label('Confirm new password'),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _confirmation,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _savePassword(),
                          cursorColor: VColors.prune,
                          decoration: const InputDecoration(
                            hintText: 'Type it again',
                            prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: VColors.red,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: VColors.red,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : switch (_step) {
                                  1 => _sendCode,
                                  2 => _verifyCode,
                                  _ => _savePassword,
                                },
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: VColors.lin,
                                  ),
                                )
                              : Text(
                                  switch (_step) {
                                    1 => 'Send reset code',
                                    2 => 'Verify code',
                                    _ => 'Save new password',
                                  },
                                ),
                        ),
                      ),
                      if (_step < 3) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _sendCode,
                            child: const Text('Send the code again'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetHeader extends StatelessWidget {
  const _ResetHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topInset + 10, 24, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VColors.pruneLight, VColors.prune],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                tooltip: 'Back to sign in',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Reset password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: VColors.lin,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'TRANSPORT DRIVER',
                  style: TextStyle(
                    color: VColors.lin,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VColors.ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
