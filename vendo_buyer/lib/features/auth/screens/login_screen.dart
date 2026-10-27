import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/auth/screens/register_screen.dart';
import 'package:vendo_buyer/features/home/screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the rider app
//  • Prune   → header, main button, main text
//  • Brique  → small accent (register link)
//  • Lin     → soft gold for the tagline
//  • Raisin  → icons and links
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF412143);
  static const pruneLight = Color(0xFF55295A);
  static const brique = Color(0xFFBF5E40);
  static const lin = Color(0xFFDBC583);
  static const raisin = Color(0xFF815488);

  static const background = Color(0xFFFAF7F5);
  static const ink = Color(0xFF2A1B2C);
  static const muted = Color(0xFF8C8290);
  static const border = Color(0xFFECE6EA);
}

const double _radius = 14;

// Size of the empty spot in the header where the logo sits
const double _logoBoxW = 140;
const double _logoBoxH = 105;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loggingIn = false;

  // Entrance animation
  late final AnimationController _enter;
  late final AnimationController _ambient;

  static const _cardCurve = Interval(0.20, 0.90, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _enter.dispose();
    _ambient.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loggingIn) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Enter your email and password.');
      return;
    }
    setState(() => _loggingIn = true);
    try {
      await BuyerApi.instance.login(email, password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on BuyerApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted)
        _snack('Cannot reach Vendo. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  void _onGoogleSignIn() {
    _snack('Google sign-in coming soon.');
  }

  void _onForgotPassword() {}

  void _onRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.prune,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                // The page always fills the screen, and scrolls when the
                // keyboard is open or the screen is small.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_C.pruneLight, _C.prune],
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _HeaderSection(
                            enter: _enter,
                            ambient: _ambient,
                          ),
                        ),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _enter,
                            // The card slides up and fades in
                            child: _FormCard(
                              emailCtrl: _emailCtrl,
                              passwordCtrl: _passwordCtrl,
                              obscure: _obscure,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                              onLogin: _onLogin,
                              loggingIn: _loggingIn,
                              onGoogle: _onGoogleSignIn,
                              onForgot: _onForgotPassword,
                              onRegister: _onRegister,
                            ),
                            builder: (context, child) {
                              final v = _cardCurve.transform(_enter.value);
                              return Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  offset: Offset(0, 70 * (1 - v)),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: logo, "Vendo", welcome text
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final Animation<double> enter;
  final Animation<double> ambient;

  const _HeaderSection({required this.enter, required this.ambient});

  static const _logoCurve = Interval(0.0, 0.50, curve: Curves.easeOutBack);
  static const _textCurve = Interval(0.35, 0.90, curve: Curves.easeOut);

  // The moving elements fade in after the logo has started to pop in
  static const _ambientFade = Interval(0.20, 0.80, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Moving elements: only inside the purple header. They reach 28px
        // below it so they also show in the gaps next to the card's rounded
        // corners; the white card itself covers them.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -28,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([ambient, enter]),
                builder: (context, _) => CustomPaint(
                  painter: _HeaderAmbientPainter(
                    t: ambient.value,
                    fade: _ambientFade.transform(enter.value),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Header content (logo + texts)
        Padding(
          padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 36),
          child: Column(
            children: [
              SizedBox(
                width: _logoBoxW,
                height: _logoBoxH,
                child: Center(
                  child: AnimatedBuilder(
                    animation: enter,
                    child: const _VendoBagLogo(),
                    builder: (context, child) {
                      final v = _logoCurve.transform(enter.value);
                      return Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * v,
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: enter,
                child: const _HeaderTexts(),
                builder: (context, child) {
                  final v = _textCurve.transform(enter.value);
                  return Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - v)),
                      child: child,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderTexts extends StatelessWidget {
  const _HeaderTexts();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Vendo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'BUY. SELL. DELIVERED',
          style: TextStyle(
            color: _C.lin,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Welcome Back!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Find What You Love, Vendo it.',
          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Moving elements for the purple header
//
// `t` loops from 0.0 to 1.0 (14 seconds). Every movement uses whole sine
// cycles or wrapped values, so the loop has no jump when it restarts.
// `fade` (0 → 1) fades everything in during the screen entrance.
// ─────────────────────────────────────────────────────────────────────────────

// Stable pseudo-random number in [0, 1), so the stars stay in the same places.
double _hash(int n) {
  final x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

class _FloatingDot {
  final double x, phase, size;
  final int cycles; // how many times it rises per loop (whole number)
  final Color color;

  const _FloatingDot(this.x, this.phase, this.cycles, this.size, this.color);
}

class _HeaderAmbientPainter extends CustomPainter {
  final double t, fade;

  _HeaderAmbientPainter({required this.t, required this.fade});

  static const _twoPi = math.pi * 2;

  static const _dots = <_FloatingDot>[
    _FloatingDot(0.10, 0.00, 1, 3.0, _C.lin),
    _FloatingDot(0.24, 0.40, 1, 2.0, _C.brique),
    _FloatingDot(0.38, 0.75, 2, 2.5, _C.lin),
    _FloatingDot(0.52, 0.20, 1, 3.5, _C.brique),
    _FloatingDot(0.66, 0.60, 1, 2.0, _C.lin),
    _FloatingDot(0.80, 0.90, 2, 3.0, _C.brique),
    _FloatingDot(0.92, 0.45, 1, 2.0, _C.lin),
  ];

  // x position (fraction of width), y (fraction of height), length, speed
  // (whole number of passes per loop), alpha
  static const _streaks = <List<double>>[
    [0.15, 0.16, 120, 1, 0.20],
    [0.70, 0.30, 160, 2, 0.16],
    [0.40, 0.62, 140, 1, 0.18],
    [0.90, 0.78, 110, 2, 0.14],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0.01) return;

    // Safety: never paint outside this box
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;
    final a = t * _twoPi;

    // 1) Soft circles drifting in slow loops
    final topRight = Offset(
      w * 0.88 + math.sin(a) * 18,
      h * 0.14 + math.cos(a) * 14,
    );
    canvas.drawCircle(
      topRight,
      90,
      Paint()..color = Colors.white.withAlpha((16 * fade).round()),
    );
    canvas.drawCircle(
      Offset(w * 0.06 + math.cos(a) * 16, h * 0.78 + math.sin(a) * 12),
      80,
      Paint()..color = _C.raisin.withAlpha((46 * fade).round()),
    );
    canvas.drawCircle(
      Offset(w * 0.50 - math.sin(a) * 24, h * 0.45 + math.cos(a * 2) * 10),
      46,
      Paint()..color = Colors.white.withAlpha((9 * fade).round()),
    );

    // 2) Two thin rings that expand from the top-right circle and fade
    for (final phase in const [0.0, 0.5]) {
      final p = (t * 2 + phase) % 1.0; // 0 → 1, twice per loop
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _C.lin.withAlpha(((1 - p) * 55 * fade).round().clamp(0, 255));
      canvas.drawCircle(topRight, 40 + p * 100, ring);
    }

    // 3) Twinkling stars
    final star = Paint();
    for (int i = 0; i < 26; i++) {
      final x = _hash(i * 3 + 1) * w;
      final y = _hash(i * 3 + 2) * h * 0.92;
      final r = 0.7 + _hash(i * 3 + 3) * 1.2;
      final twinkle = 0.5 + 0.5 * math.sin(a * 3 + i * 1.9);
      star.color = Colors.white.withAlpha(
        ((25 + 105 * twinkle) * fade).round().clamp(0, 255),
      );
      canvas.drawCircle(Offset(x, y), r, star);
    }

    // 4) Dots floating up, fading in and out
    for (final d in _dots) {
      final prog = (t * d.cycles + d.phase) % 1.0; // 0 bottom → 1 top
      final y = h - prog * h;
      final x = w * d.x + math.sin((t * d.cycles + d.phase) * _twoPi) * 10;
      final alpha = (math.sin(prog * math.pi) * 140 * fade).round().clamp(
        0,
        255,
      );
      canvas.drawCircle(
        Offset(x, y),
        d.size,
        Paint()..color = d.color.withAlpha(alpha),
      );
    }

    // 5) A few faint wind streaks drifting left
    for (final s in _streaks) {
      final length = s[2];
      final span = w + length;
      final headX = ((s[0] * w) - t * span * s[3]) % span;
      final y = s[1] * h;
      final alpha = (s[4] * fade * 255).round().clamp(0, 255);

      final rect = Rect.fromLTWH(headX - length, y, length, 1);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withAlpha(alpha), Colors.white.withAlpha(0)],
        ).createShader(rect)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(headX - length, y), Offset(headX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderAmbientPainter old) =>
      old.t != t || old.fade != fade;
}

// ─────────────────────────────────────────────────────────────────────────────
// White form card
// ─────────────────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onLogin;
  final bool loggingIn;
  final VoidCallback onGoogle;
  final VoidCallback onForgot;
  final VoidCallback onRegister;

  const _FormCard({
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email
          const _Label('Email Address'),
          const SizedBox(height: 8),
          _InputField(
            controller: emailCtrl,
            hint: 'user@email.com',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Label('Password'),
              GestureDetector(
                onTap: onForgot,
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: _C.raisin,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InputField(
            controller: passwordCtrl,
            hint: '••••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onLogin(),
            suffix: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _C.muted,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: loggingIn ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.prune,
                disabledBackgroundColor: _C.prune,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: loggingIn
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _C.lin,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Signing in…',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // "or" divider
          const Row(
            children: [
              Expanded(child: Divider(thickness: 1, color: _C.border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: _C.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(thickness: 1, color: _C.border)),
            ],
          ),
          const SizedBox(height: 20),

          // Google button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: onGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: _C.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),
          const SizedBox(height: 24),

          // Register
          Center(
            child: GestureDetector(
              onTap: onRegister,
              behavior: HitTestBehavior.opaque,
              child: RichText(
                text: const TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: _C.muted, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Register here.',
                      style: TextStyle(
                        color: _C.brique,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _C.ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboard,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      cursorColor: _C.prune,
      style: const TextStyle(color: _C.ink, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.muted, fontSize: 15),
        filled: true,
        fillColor: _C.background,
        prefixIcon: Icon(icon, color: _C.raisin, size: 20),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(_C.border, 1.2),
        enabledBorder: border(_C.border, 1.2),
        focusedBorder: border(_C.prune, 1.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vendo logo image
// ─────────────────────────────────────────────────────────────────────────────
class _VendoBagLogo extends StatelessWidget {
  const _VendoBagLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/vendo_app_logo.png',
      width: 90,
      height: 90,
      fit: BoxFit.contain,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google logo (keeps Google's own brand colors, as required)
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

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
