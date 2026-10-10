import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/auth/screens/forgot_password_screen.dart';
import 'package:vendo_rider/features/auth/screens/register_screen.dart';
import 'package:vendo_rider/features/dashboard/screens/navigation_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the rest of the app
//  • Prune   → header, main button, main text
//  • Brique  → small accent (register link)
//  • Lin     → soft gold for the "Xpress" name and tagline
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
  static const raisinSoft = Color(0xFFF4EDF5);
}

const double _radius = 14;

// ── Rider sizes ──────────────────────────────────────────────────────────────
// On the splash screen the rider is 160 x 120, centered at 36% of the screen
// height. On this screen it settles into the header at 140 x 105.
const double _splashRiderW = 160;
const double _splashRiderCenterY = 0.36; // same value the splash screen uses
const double _riderW = 140;
const double _riderH = 105;

class LoginScreen extends StatefulWidget {
  /// Set to false to skip the "rider glides in from the splash" animation
  /// (for example when the login screen is opened after logging out).
  final bool animateEntrance;

  const LoginScreen({super.key, this.animateEntrance = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loggingIn = false;
  bool _googleBusy = false;
  Future<void>? _googleInitialized;

  // ── Entrance animation (rider blends in from the splash screen) ─────────
  //  0.00 – 0.30  hold: the splash is still fading out under this screen,
  //               and the rider stays exactly where the splash rider is
  //  0.30 – 0.80  the rider glides up to the logo spot in the header
  //  0.42 – 0.95  the white form card slides up
  //  0.55 – 1.00  name, tagline and welcome text fade in
  late final AnimationController _enter;

  // Loops forever: drives the moving elements in the purple header only
  late final AnimationController _ambient;

  final LayerLink _riderLink = LayerLink();
  final GlobalKey _riderKey = GlobalKey();
  Offset? _riderStart; // where the rider starts, relative to its final spot
  Size? _bodySize;

  static const _moveCurve = Interval(0.30, 0.80, curve: Curves.easeInOutCubic);
  static const _cardCurve = Interval(0.42, 0.95, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    if (widget.animateEntrance) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEntrance());
    } else {
      _riderStart = Offset.zero;
      _enter.value = 1.0;
    }
  }

  // Measure where the rider will end up, then work out how far away the
  // splash rider is from that spot, so both riders line up perfectly.
  void _startEntrance() {
    if (!mounted) return;

    var start = Offset.zero;
    final box = _riderKey.currentContext?.findRenderObject();
    final body = _bodySize;
    if (box is RenderBox && box.hasSize && body != null) {
      final center = box.localToGlobal(box.size.center(Offset.zero));
      start = Offset(
        body.width / 2 - center.dx,
        body.height * _splashRiderCenterY - center.dy,
      );
    }
    setState(() => _riderStart = start);
    _enter.forward();
  }

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
              'Cannot reach Vendo Xpress. Check your connection and retry.',
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
    _enter.dispose();
    _ambient.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
            _bodySize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              children: [
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    // The page always fills the screen, and scrolls when the
                    // keyboard is open or the screen is small.
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
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
                            // Full width, so the moving elements reach the left
                            // and right edges of the screen
                            SizedBox(
                              width: double.infinity,
                              child: _HeaderSection(
                                riderLink: _riderLink,
                                riderKey: _riderKey,
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
                                  onLogin: _login,
                                  loggingIn: _loggingIn,
                                  onGoogle: _continueWithGoogle,
                                  googleBusy: _googleBusy,
                                  onForgot: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  ),
                                  onRegister: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
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
                ),

                // The rider, drawn above everything while it glides up.
                // It is glued to the empty spot in the header, so it also
                // scrolls with the header afterwards.
                Positioned(left: 0, top: 0, child: _buildRiderOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRiderOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, _) {
          final start = _riderStart;
          if (start == null) return const SizedBox.shrink(); // not measured yet

          // 0 = still on the splash spot, 1 = settled in the header
          final move = _moveCurve.transform(_enter.value);
          final startScale = _splashRiderW / _riderW;

          return CompositedTransformFollower(
            link: _riderLink,
            showWhenUnlinked: false,
            offset: start * (1 - move),
            child: Transform.scale(
              scale: 1 + (startScale - 1) * (1 - move),
              child: const SizedBox(
                width: _riderW,
                height: _riderH,
                child: _RiderPicture(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: rider spot, "Vendo Xpress", welcome text
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final LayerLink riderLink;
  final GlobalKey riderKey;
  final Animation<double> enter;
  final Animation<double> ambient;

  const _HeaderSection({
    required this.riderLink,
    required this.riderKey,
    required this.enter,
    required this.ambient,
  });

  static const _textCurve = Interval(0.55, 1.0, curve: Curves.easeOut);

  // The moving elements fade in after the rider has started to glide up
  static const _ambientFade = Interval(0.35, 0.9, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      alignment: Alignment.topCenter, // keeps the rider and texts centered
      clipBehavior: Clip.none,
      children: [
        // Moving elements: only inside the purple header. They reach 28px
        // below it so they also show in the gaps next to the card's rounded
        // corners; the white card itself covers them, so nothing moves on
        // the white part.
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

        // Header content (rider spot + texts)
        Padding(
          padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 36),
          child: Column(
            children: [
              // Empty spot where the rider lands (the rider itself is drawn by
              // the overlay in LoginScreen)
              CompositedTransformTarget(
                link: riderLink,
                child: SizedBox(key: riderKey, width: _riderW, height: _riderH),
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

// ─────────────────────────────────────────────────────────────────────────────
// Moving elements for the purple header
//
// `t` loops from 0.0 to 1.0 (14 seconds). Every movement uses whole sine
// cycles or wrapped values, so the loop has no jump when it restarts.
//  • soft glowing circles that drift slowly
//  • two thin rings that expand and fade (a quiet pulse)
//  • twinkling stars
//  • small gold / orange-red dots floating up
//  • a few faint wind streaks passing by
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

class _HeaderTexts extends StatelessWidget {
  const _HeaderTexts();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Brand name: "Vendo" in white, "Xpress" in soft gold
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Vendo ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                TextSpan(
                  text: 'Xpress',
                  style: TextStyle(
                    color: _C.lin,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
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
          'Welcome Back, Rider!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Deliver with Vendo Xpress.',
          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
        ),
      ],
    );
  }
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
  final bool googleBusy;
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
    required this.googleBusy,
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
              onPressed: googleBusy ? null : onGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: _C.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: googleBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _C.raisin,
                      ),
                    )
                  : const Row(
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
// The rider: the same drawing the splash screen ends with
//
// This is a copy of `_RiderPainter` from splash_screen.dart, drawn in the pose
// the splash rider has when it stops (engine idling, wheels at rest, brake
// light off). Because it is the same picture at the same spot, the splash
// rider and this one overlap exactly, so the change between screens is
// invisible. If you ever change the rider in the splash screen, change it
// here too.
// ─────────────────────────────────────────────────────────────────────────────
class _RiderPicture extends StatelessWidget {
  const _RiderPicture();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RiderPainter(
        wheelAngle: 2600 / 20, // wheel position when the splash rider stops
        speed: 0,
        brake: 0,
        phase: 1,
      ),
    );
  }
}

// Person on a motorcycle with a delivery box, drawn in a 160 x 120 box and
// scaled to fit. Faces right.
class _RiderPainter extends CustomPainter {
  final double wheelAngle, speed, brake, phase;

  _RiderPainter({
    required this.wheelAngle,
    required this.speed,
    required this.brake,
    required this.phase,
  });

  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _fill(Color c) => Paint()..color = c;

  void _wheel(Canvas canvas, Offset c) {
    final blur = (speed * 2.2).clamp(0.0, 1.0); // 1 = blurry, 0 = clear

    if (blur > 0.02) {
      canvas.drawCircle(
        c,
        15,
        _fill(Colors.white.withAlpha((blur * 50).round())),
      );
    }
    // tire + rim
    canvas.drawCircle(c, 17.5, _stroke(const Color(0xFFEFE6F2), 5.5));
    canvas.drawCircle(c, 11.5, _stroke(_C.lin.withAlpha(150), 1.5));

    // spokes + a marker dot, only visible when the wheel is slower
    final clear = ((1 - blur) * 255).round();
    if (clear > 4) {
      final spoke = _stroke(_C.lin.withAlpha(clear), 2);
      for (int i = 0; i < 3; i++) {
        final a = wheelAngle + i * math.pi / 3;
        final d = Offset(math.cos(a), math.sin(a)) * 11.5;
        canvas.drawLine(c - d, c + d, spoke);
      }
      final m = c + Offset(math.cos(wheelAngle), math.sin(wheelAngle)) * 11.5;
      canvas.drawCircle(m, 1.8, _fill(_C.brique.withAlpha(clear)));
    }
    canvas.drawCircle(c, 3.5, _fill(_C.lin));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 120);

    const rear = Offset(40, 76);
    const front = Offset(122, 76);
    const jacket = Color(0xFFEADFF0);
    const jacketShade = Color(0xFFCDB9D6);
    const pants = Color(0xFF2B1530);
    const dark = Color(0xFF1F0F21);
    const red = Color(0xFFFF3B30);

    // Headlight glow
    canvas.drawCircle(
      const Offset(123, 50),
      12,
      Paint()
        ..color = _C.lin.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Wheels and fenders
    _wheel(canvas, rear);
    _wheel(canvas, front);
    canvas.drawArc(
      Rect.fromCircle(center: rear, radius: 23),
      math.pi * 1.1,
      math.pi * 0.75,
      false,
      _stroke(_C.lin, 3),
    );
    canvas.drawArc(
      Rect.fromCircle(center: front, radius: 23),
      math.pi * 1.2,
      math.pi * 0.7,
      false,
      _stroke(_C.lin, 3),
    );

    // Delivery box on a rack
    canvas.drawLine(
      const Offset(14, 61),
      const Offset(52, 61),
      _stroke(_C.lin, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 31, 40, 29),
        const Radius.circular(5),
      ),
      _fill(_C.brique),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 31, 40, 8),
        const Radius.circular(4),
      ),
      _fill(Colors.black.withAlpha(45)),
    );
    // "V" logo on the box
    canvas.drawPath(
      Path()
        ..moveTo(25, 43)
        ..lineTo(32, 55)
        ..lineTo(39, 43),
      _stroke(Colors.white, 3.2),
    );

    // Tail light (glows when braking)
    if (brake > 0.02) {
      canvas.drawCircle(
        const Offset(10, 50),
        10,
        Paint()
          ..color = red.withAlpha((160 * brake).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(
      const Offset(12, 50),
      2.6,
      _fill(Color.lerp(const Color(0xFF7A2A22), red, brake)!),
    );

    // Bike body
    final bike = _stroke(_C.lin, 5);
    canvas.drawLine(rear, const Offset(68, 69), bike); // swingarm
    canvas.drawLine(const Offset(110, 41), front, bike); // fork
    canvas.drawLine(
      const Offset(113, 52),
      const Offset(120, 70),
      _stroke(Colors.white.withAlpha(150), 1.8),
    ); // fork shine
    canvas.drawLine(
      const Offset(64, 78),
      const Offset(34, 82),
      _stroke(_C.raisin, 4.5),
    ); // exhaust
    canvas.drawCircle(const Offset(33, 82), 2.8, _fill(_C.raisin));

    // engine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 62, 28, 18),
        const Radius.circular(5),
      ),
      _fill(_C.lin),
    );
    canvas.drawRect(
      const Rect.fromLTWH(70, 66, 12, 8),
      _fill(_C.prune.withAlpha(120)),
    );
    // seat
    canvas.drawPath(
      Path()
        ..moveTo(44, 57)
        ..lineTo(78, 55)
        ..lineTo(80, 61)
        ..lineTo(46, 63)
        ..close(),
      _fill(dark),
    );
    // fuel tank
    canvas.drawPath(
      Path()
        ..moveTo(72, 56)
        ..quadraticBezierTo(88, 38, 108, 50)
        ..lineTo(106, 60)
        ..lineTo(76, 62)
        ..close(),
      _fill(_C.lin),
    );
    // handlebar + headlight
    canvas.drawLine(
      const Offset(106, 41),
      const Offset(115, 38),
      _stroke(Colors.white, 3.5),
    );
    canvas.drawCircle(const Offset(122, 50), 6, _fill(Colors.white));
    canvas.drawCircle(const Offset(122, 50), 3.5, _fill(_C.lin));

    // ── Rider ──────────────────────────────────────────────────────────
    // leg (outlined so it stands out from the dark background)
    final leg = Path()
      ..moveTo(68, 52)
      ..lineTo(92, 59)
      ..lineTo(83, 79);
    canvas.drawPath(leg, _stroke(_C.raisin.withAlpha(200), 12));
    canvas.drawPath(leg, _stroke(pants, 9));
    canvas.drawLine(
      const Offset(83, 80),
      const Offset(95, 82),
      _stroke(Colors.white, 5.5),
    );

    // torso, leaning forward
    canvas.drawLine(
      const Offset(66, 53),
      const Offset(84, 29),
      _stroke(_C.raisin.withAlpha(180), 19),
    );
    canvas.drawLine(
      const Offset(66, 53),
      const Offset(84, 29),
      _stroke(jacket, 17),
    );
    canvas.drawLine(
      const Offset(68, 36),
      const Offset(82, 46),
      _stroke(_C.lin, 3),
    ); // jacket stripe

    // arm to the handlebar + glove
    final arm = Path()
      ..moveTo(82, 32)
      ..lineTo(95, 45)
      ..lineTo(110, 41);
    canvas.drawPath(arm, _stroke(jacketShade, 6.5));
    canvas.drawCircle(const Offset(111, 41), 3.6, _fill(_C.prune));

    // scarf: streams back when fast, droops when stopped
    final scarf = Path()..moveTo(80, 28);
    final len = 0.35 + speed * 0.65;
    for (int k = 1; k <= 6; k++) {
      final x = 80 - k * 5.5 * len;
      final y =
          28 +
          k * 1.4 * (1 - speed) +
          math.sin(phase * math.pi * 14 + k * 0.9) * (0.8 + k * 0.55) * speed;
      scarf.lineTo(x, y);
    }
    canvas.drawPath(scarf, _stroke(_C.lin, 4.5));

    // helmet with visor
    const head = Offset(90, 16);
    canvas.drawCircle(head, 10.5, _fill(_C.brique));
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: 7),
      math.pi * 1.15,
      math.pi * 0.6,
      false,
      _stroke(_C.lin, 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(93, 11.5, 11, 7),
        const Radius.circular(3.5),
      ),
      _fill(dark),
    );
    canvas.drawLine(
      const Offset(96, 13.5),
      const Offset(101, 13.5),
      _stroke(Colors.white.withAlpha(180), 1.3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RiderPainter old) =>
      old.wheelAngle != wheelAngle ||
      old.speed != speed ||
      old.brake != brake ||
      old.phase != phase;
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