import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vendo_rider/core/theme/app_colors.dart';
import 'package:vendo_rider/features/auth/screens/register_screen.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/screens/navigation_bar.dart';
import 'package:vendo_rider/features/auth/screens/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loggingIn = false;
  bool _googleBusy = false;
  Future<void>? _googleInitialized;

  Future<void> _login() async {
    if (_loggingIn) return;
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }
    setState(() => _loggingIn = true);
    try {
      await RiderApi.instance.login(_emailCtrl.text, _passwordCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on RiderApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot reach Vendo. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_googleBusy || _loggingIn) return;
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google sign-in is available on Android, iOS, and macOS. Use email verification on Linux desktop.',
          ),
        ),
      );
      return;
    }
    setState(() => _googleBusy = true);
    try {
      const serverClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
      const macosClientId = String.fromEnvironment('GOOGLE_MACOS_CLIENT_ID');
      final nativeClientId = defaultTargetPlatform == TargetPlatform.macOS
          ? macosClientId
          : iosClientId;
      _googleInitialized ??= GoogleSignIn.instance.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
        clientId: nativeClientId.isEmpty ? null : nativeClientId,
      );
      await _googleInitialized;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const RiderApiException(
          'Google did not return a verified sign-in token. Check the app OAuth client configuration.',
        );
      }
      final result = await RiderApi.instance.googleSignIn(idToken);
      if (!mounted) return;
      if (result['registration_required'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              googleRegistrationToken: result['registration_token'] as String,
              verifiedEmail: result['email'] as String,
              googleFirstName: result['first_name']?.toString() ?? '',
              googleLastName: result['last_name']?.toString() ?? '',
            ),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on RiderApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google sign-in could not complete. Check the configured Android/iOS OAuth client and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.headerBg,
      body: Column(
        children: [
          Expanded(flex: 42, child: _HeaderSection()),
          Expanded(
            flex: 58,
            child: _BottomCard(
              emailCtrl: _emailCtrl,
              passwordCtrl: _passwordCtrl,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              onLogin: _login,
              loggingIn: _loggingIn,
              onGoogle: _continueWithGoogle,
              onForgot: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              ),
              onRegister: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1F52), Color(0xFF2A1440)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _VendoBagLogo(),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'vendo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'BUY. SELL. DELIVERED',
                      style: TextStyle(
                        color: Color(0xFFE8873A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome Back, Rider!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Deliver with Vendo.',
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onLogin;
  final bool loggingIn;
  final VoidCallback onGoogle;
  final VoidCallback onForgot;
  final VoidCallback onRegister;

  const _BottomCard({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggle,
    required this.onLogin,
    required this.loggingIn,
    required this.onGoogle,
    required this.onForgot,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email
            const Text(
              'Email Address',
              style: TextStyle(
                color: AppColors.labelDark,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _InputField(
              controller: emailCtrl,
              hint: 'user@email.com',
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    color: AppColors.labelDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: onForgot,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppColors.accentPurple,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accentPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InputField(
              controller: passwordCtrl,
              hint: '••••••••••',
              obscure: obscure,
              suffix: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure
                      ? Icons.remove_red_eye_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF888888),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loggingIn ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  loggingIn ? 'Signing in…' : 'Login',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // OR divider
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFDDDDDD),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Google button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleLogo(),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Register
            Center(
              child: GestureDetector(
                onTap: onRegister,
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Register here.',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Color(0xFF333333), fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 14.5),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _VendoBagLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(78, 88), painter: _BagPainter()),
          const Positioned(
            bottom: 16,
            child: Text(
              'v',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawLayer(
      double l,
      double r,
      double t,
      double b,
      Color color,
      double radius,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(l + radius, t)
        ..lineTo(r - radius, t)
        ..quadraticBezierTo(r, t, r, t + radius)
        ..lineTo(r, b - radius)
        ..quadraticBezierTo(r, b, r - radius, b)
        ..lineTo(l + radius, b)
        ..quadraticBezierTo(l, b, l, b - radius)
        ..lineTo(l, t + radius)
        ..quadraticBezierTo(l, t, l + radius, t)
        ..close();
      canvas.drawPath(path, paint);
    }

    drawLayer(
      w * 0.18,
      w * 0.98,
      h * 0.28,
      h * 0.98,
      const Color(0xFFE8873A),
      10,
    );
    drawLayer(
      w * 0.10,
      w * 0.90,
      h * 0.28,
      h * 0.94,
      const Color(0xFFB8860B),
      10,
    );
    drawLayer(
      w * 0.02,
      w * 0.82,
      h * 0.28,
      h * 0.90,
      const Color(0xFFF0EEF5),
      10,
    );

    final cx = (w * 0.02 + w * 0.82) / 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * 0.28),
        width: (w * 0.82 - w * 0.02) * 0.40,
        height: h * 0.22,
      ),
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = const Color(0xFFF0EEF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    final eyeY = h * 0.28 + (h * 0.90 - h * 0.28) * 0.28;
    final dp = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - (w * 0.82 - w * 0.02) * 0.22, eyeY), 3.5, dp);
    canvas.drawCircle(Offset(cx + (w * 0.82 - w * 0.02) * 0.22, eyeY), 3.5, dp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(24, 24), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final sw = size.width * 0.18;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - sw / 2);

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(-1.5708, 1.5708, const Color(0xFFEA4335));
    arc(0, 1.5708, const Color(0xFFFBBC05));
    arc(1.5708, 1.5708, const Color(0xFF34A853));
    arc(3.14159, 1.5708, const Color(0xFF4285F4));

    canvas.drawCircle(
      Offset(cx, cy),
      r - sw,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    canvas.drawRect(
      Rect.fromLTWH(cx - 0.5, cy - sw * 0.45, r - sw * 0.3, sw * 0.9),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawArc(
      rect,
      -0.45,
      0.45,
      false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
