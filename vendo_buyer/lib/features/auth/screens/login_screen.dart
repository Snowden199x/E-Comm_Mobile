import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/theme/app_colors.dart';
import 'package:vendo_buyer/features/auth/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {}

  void _onGoogleSignIn() {}

  void _onForgotPassword() {}

  void _onRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.headerBackground,
      body: Column(
        children: [
          // ── Top purple header section ──────────────────────────────
          Expanded(flex: 42, child: _HeaderSection()),

          // ── Bottom white card section ──────────────────────────────
          Expanded(
            flex: 58,
            child: _BottomCard(
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: _obscurePassword,
              onTogglePassword: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onLogin: _onLogin,
              onGoogleSignIn: _onGoogleSignIn,
              onForgotPassword: _onForgotPassword,
              onRegister: _onRegister,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Section
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
            const SizedBox(height: 8),
            // Logo row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Vendo bag logo
                _VendoBagLogo(),
                const SizedBox(width: 12),
                // Brand name + tagline
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'vendo',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        height: 1.0,
                      ),
                    ),
                    const Text(
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
            // Welcome text
            const Text(
              'Welcome Back!',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle
            const Text(
              'Find What You Love, Vendo it.',
              style: TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
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
// Vendo Bag Logo Widget
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
          // Bag shape
          CustomPaint(size: const Size(78, 88), painter: _BagPainter()),
          // "v" letter centered in the bag
          const Positioned(
            bottom: 16,
            child: Text(
              'v',
              style: TextStyle(
                color: AppColors.white,
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

// ─────────────────────────────────────────────────────────────────────────────
// Bag Painter — draws the shopping bag shape with handle and decorative layers
// ─────────────────────────────────────────────────────────────────────────────
class _BagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Orange accent layer (slightly offset right/down) ────────────
    final accentPaint = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;

    final accentPath = Path();
    final accentLeft = w * 0.18;
    final accentRight = w * 0.98;
    final accentTop = h * 0.28;
    final accentBottom = h * 0.98;
    final accentRadius = 10.0;
    accentPath.moveTo(accentLeft + accentRadius, accentTop);
    accentPath.lineTo(accentRight - accentRadius, accentTop);
    accentPath.quadraticBezierTo(
      accentRight,
      accentTop,
      accentRight,
      accentTop + accentRadius,
    );
    accentPath.lineTo(accentRight, accentBottom - accentRadius);
    accentPath.quadraticBezierTo(
      accentRight,
      accentBottom,
      accentRight - accentRadius,
      accentBottom,
    );
    accentPath.lineTo(accentLeft + accentRadius, accentBottom);
    accentPath.quadraticBezierTo(
      accentLeft,
      accentBottom,
      accentLeft,
      accentBottom - accentRadius,
    );
    accentPath.lineTo(accentLeft, accentTop + accentRadius);
    accentPath.quadraticBezierTo(
      accentLeft,
      accentTop,
      accentLeft + accentRadius,
      accentTop,
    );
    accentPath.close();
    canvas.drawPath(accentPath, accentPaint);

    // ── Brown/tan layer (slightly offset right) ──────────────────────
    final brownPaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.fill;

    final brownPath = Path();
    final bLeft = w * 0.10;
    final bRight = w * 0.90;
    final bTop = h * 0.28;
    final bBottom = h * 0.94;
    final bRadius = 10.0;
    brownPath.moveTo(bLeft + bRadius, bTop);
    brownPath.lineTo(bRight - bRadius, bTop);
    brownPath.quadraticBezierTo(bRight, bTop, bRight, bTop + bRadius);
    brownPath.lineTo(bRight, bBottom - bRadius);
    brownPath.quadraticBezierTo(bRight, bBottom, bRight - bRadius, bBottom);
    brownPath.lineTo(bLeft + bRadius, bBottom);
    brownPath.quadraticBezierTo(bLeft, bBottom, bLeft, bBottom - bRadius);
    brownPath.lineTo(bLeft, bTop + bRadius);
    brownPath.quadraticBezierTo(bLeft, bTop, bLeft + bRadius, bTop);
    brownPath.close();
    canvas.drawPath(brownPath, brownPaint);

    // ── Main white/light bag body ────────────────────────────────────
    final bagPaint = Paint()
      ..color = const Color(0xFFF0EEF5)
      ..style = PaintingStyle.fill;

    final bagPath = Path();
    final left = w * 0.02;
    final right = w * 0.82;
    final top = h * 0.28;
    final bottom = h * 0.90;
    final radius = 10.0;
    bagPath.moveTo(left + radius, top);
    bagPath.lineTo(right - radius, top);
    bagPath.quadraticBezierTo(right, top, right, top + radius);
    bagPath.lineTo(right, bottom - radius);
    bagPath.quadraticBezierTo(right, bottom, right - radius, bottom);
    bagPath.lineTo(left + radius, bottom);
    bagPath.quadraticBezierTo(left, bottom, left, bottom - radius);
    bagPath.lineTo(left, top + radius);
    bagPath.quadraticBezierTo(left, top, left + radius, top);
    bagPath.close();
    canvas.drawPath(bagPath, bagPaint);

    // ── Bag handle ───────────────────────────────────────────────────
    final handlePaint = Paint()
      ..color = const Color(0xFFF0EEF5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final handleCenter = (left + right) / 2;
    final handleRect = Rect.fromCenter(
      center: Offset(handleCenter, top),
      width: (right - left) * 0.40,
      height: h * 0.22,
    );
    canvas.drawArc(handleRect, 3.14159, 3.14159, false, handlePaint);

    // ── Two small eyes / dots on the bag ────────────────────────────
    final dotPaint = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;

    final eyeY = top + (bottom - top) * 0.28;
    final eyeSpacing = (right - left) * 0.22;
    final eyeRadius = 3.5;
    canvas.drawCircle(
      Offset(handleCenter - eyeSpacing, eyeY),
      eyeRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(handleCenter + eyeSpacing, eyeY),
      eyeRadius,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom White Card
// ─────────────────────────────────────────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  const _BottomCard({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onGoogleSignIn,
    required this.onForgotPassword,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F5FB),
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
            // ── Email Address ─────────────────────────────────────────
            const Text(
              'Email Address',
              style: TextStyle(
                color: Color(0xFF2A1440),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            _InputField(
              controller: emailController,
              hintText: 'user@email.com',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            // ── Password row with Forgot Password ────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    color: Color(0xFF2A1440),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                GestureDetector(
                  onTap: onForgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Color(0xFF7B2FBE),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF7B2FBE),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InputField(
              controller: passwordController,
              hintText: '••••••••••',
              obscureText: obscurePassword,
              suffixIcon: GestureDetector(
                onTap: onTogglePassword,
                child: Icon(
                  obscurePassword
                      ? Icons.remove_red_eye_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF888888),
                  size: 22,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ── Login Button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D1B3D),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── "or" divider ──────────────────────────────────────────
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FB),
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

            // ── Continue with Google ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google "G" logo
                    _GoogleLogo(),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Don't have an account? ────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: onRegister,
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      TextSpan(
                        text: 'Register here.',
                        style: TextStyle(
                          color: Color(0xFF2D1B3D),
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
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
// Reusable Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF333333), fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14.5),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
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
// Google "G" Logo painted widget
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
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Clip to circle
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw the four colored arcs of the Google G
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: r - strokeWidth / 2,
    );

    // Red arc (top-right)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -1.5708, 1.5708, false, redPaint); // -90° to 0°

    // Yellow arc (bottom-right)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, 1.5708, false, yellowPaint); // 0° to 90°

    // Green arc (bottom-left)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 1.5708, 1.5708, false, greenPaint); // 90° to 180°

    // Blue arc (top-left)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 3.14159, 1.5708, false, bluePaint); // 180° to 270°

    // White center fill
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r - strokeWidth, whitePaint);

    // Draw the horizontal bar of the "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      cx - 0.5,
      cy - strokeWidth * 0.45,
      r - strokeWidth * 0.3,
      strokeWidth * 0.9,
    );
    canvas.drawRect(barRect, barPaint);

    // Draw the outer arc piece that makes the "G" shape
    final gArcPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -0.45, 0.45, false, gArcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
