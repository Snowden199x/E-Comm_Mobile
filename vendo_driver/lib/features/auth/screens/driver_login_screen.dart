import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vendo_driver/core/config/google_auth_config.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/auth/screens/driver_register_screen.dart';
import 'package:vendo_driver/features/auth/screens/forgot_password_screen.dart';
import 'package:vendo_driver/features/dashboard/screens/driver_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same layout and Vendo palette as the Rider login screen:
//  • Prune   → header, main button, main text
//  • Brique  → small accent (register link)
//  • Lin     → soft gold for the "Xpress" name and tagline
//  • Raisin  → icons and links
// The only change is the picture in the header: a transport truck instead of
// the motorcycle rider.
// ─────────────────────────────────────────────────────────────────────────────
const double _radius = 14;

// ── Truck sizes ──────────────────────────────────────────────────────────────
// The truck glides in at 160 x 120 from around the middle of the screen and
// settles into the header at 140 x 105.
const double _splashTruckW = 160;
const double _splashTruckCenterY = 0.36;
const double _truckW = 140;
const double _truckH = 105;

class DriverLoginScreen extends StatefulWidget {
  /// Set to false to skip the "truck glides in" animation (for example when
  /// the login screen is opened after logging out).
  final bool animateEntrance;

  const DriverLoginScreen({super.key, this.animateEntrance = true});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _googleBusy = false;
  Future<void>? _googleInitialized;
  String? _error;
  String? _pendingHub;

  // ── Entrance animation (truck settles into the header) ───────────────────
  //  0.00 – 0.30  hold: the truck stays where it starts
  //  0.30 – 0.80  the truck glides up to its spot in the header
  //  0.42 – 0.95  the white form card slides up
  //  0.55 – 1.00  name, tagline and welcome text fade in
  //
  // Both controllers are created on first use instead of in initState, so a
  // State object that outlived a hot reload (where initState does not run
  // again) can still paint the screen instead of throwing a
  // LateInitializationError.
  AnimationController? _enterCtl;
  AnimationController? _ambientCtl;

  AnimationController get _enter => _enterCtl ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  // Loops forever: drives the moving elements in the purple header only
  AnimationController get _ambient => _ambientCtl ??= AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  final LayerLink _truckLink = LayerLink();
  final GlobalKey _truckKey = GlobalKey();
  Offset? _truckStart; // where the truck starts, relative to its final spot
  Size? _bodySize;
  bool _entranceRequested = false;

  static const _moveCurve = Interval(0.30, 0.80, curve: Curves.easeInOutCubic);
  static const _cardCurve = Interval(0.42, 0.95, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _enter.reset(); // creates the controller up front
    _requestEntrance();

    DriverApi.instance.savedApplicationEmail().then((email) {
      if (mounted && email != null && _email.text.isEmpty) {
        setState(() => _email.text = email);
      }
    });
  }

  /// Starts the entrance once. Also called from `build`, so a screen that was
  /// rebuilt by a hot reload (where `initState` does not run again) still
  /// settles into its final state instead of staying invisible.
  void _requestEntrance() {
    if (_entranceRequested) return;
    _entranceRequested = true;

    if (!widget.animateEntrance) {
      _truckStart = Offset.zero;
      _enter.value = 1.0;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startEntrance());
  }

  // Measure where the truck will end up, then work out how far away its
  // starting spot is, so the glide starts from the middle of the screen.
  void _startEntrance() {
    if (!mounted) return;

    var start = Offset.zero;
    final box = _truckKey.currentContext?.findRenderObject();
    final body = _bodySize;
    if (box is RenderBox && box.hasSize && body != null) {
      final center = box.localToGlobal(box.size.center(Offset.zero));
      start = Offset(
        body.width / 2 - center.dx,
        body.height * _splashTruckCenterY - center.dy,
      );
    }
    setState(() => _truckStart = start);
    _enter.forward();
  }

  @override
  void dispose() {
    _enterCtl?.dispose();
    _ambientCtl?.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Enter your email and password.';
        _pendingHub = null;
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() {
        _error = 'Enter the email you used to apply.';
        _pendingHub = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _pendingHub = null;
    });
    try {
      final session = await DriverApi.instance.login(email, password);
      DriverStore.instance.applySession(session);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DriverShell()),
      );
    } on DriverApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _pendingHub = error.isRejected ? null : error.reviewingHub;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Cannot reach ${DriverApi.baseUrl}. Check that the server is running and you are on the same network.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Signs in with Google. The API checks the driver role, approval and hub,
  /// then returns the same session as [_signIn], so a pending application gets
  /// the same waiting banner instead of a token.
  Future<void> _signInWithGoogle() async {
    if (_googleBusy || _busy) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      setState(() {
        _error =
            'Google sign-in is available on Android, iOS, and macOS. Use email and password here.';
        _pendingHub = null;
      });
      return;
    }
    const serverClientId = GoogleAuthConfig.webClientId;
    const iosClientId = GoogleAuthConfig.iosClientId;
    const macosClientId = GoogleAuthConfig.macosClientId;
    if (defaultTargetPlatform == TargetPlatform.android &&
        serverClientId.isEmpty) {
      setState(() {
        _error =
            'This build has no Google web client ID, so Google cannot issue a token. Rebuild with --dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>.';
        _pendingHub = null;
      });
      return;
    }
    setState(() {
      _googleBusy = true;
      _error = null;
      _pendingHub = null;
    });
    try {
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
        throw const DriverApiException(
          'Google did not return a verified sign-in token. Check the app OAuth client configuration.',
        );
      }
      final session = await DriverApi.instance.googleSignIn(idToken);
      DriverStore.instance.applySession(session);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DriverShell()),
      );
    } on DriverApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _pendingHub = error.isRejected ? null : error.reviewingHub;
      });
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      setState(() {
        _error = _googleFailureMessage(e);
        _pendingHub = null;
      });
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Google sign-in could not start on this device. Try again, or sign in with your email and password.';
        _pendingHub = null;
      });
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  /// A wrong OAuth client or a client ID the build does not have is a setup
  /// problem, so the message says what to fix instead of blaming the sign-in.
  String _googleFailureMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google does not recognise this app build. Register an Android '
            'OAuth client for com.example.vendo_driver with the SHA-1 of this build '
            'in the same Google Cloud project, and check GOOGLE_WEB_CLIENT_ID '
            'matches the server.';
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in was cancelled.';
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in was interrupted. Try again.';
      default:
        final detail = e.description;
        return detail == null || detail.isEmpty
            ? 'Google sign-in failed (${e.code.name}). Try again.'
            : 'Google sign-in failed (${e.code.name}): $detail';
    }
  }

  /// Opens password recovery. Returns true when the password was changed, so
  /// the screen can name the address that is ready to sign in.
  Future<void> _openResetSheet() async {
    final email = _email.text.trim();
    if (email.isNotEmpty && email.contains('@')) _password.clear();
    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ForgotPasswordScreen(initialEmail: email),
      ),
    );
    if (reset == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset. Sign in with your new password.'),
        ),
      );
    }
  }

  Future<void> _openStatusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ApplicationStatusSheet(
        initialEmail: _email.text.trim(),
        bottomInset: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _requestEntrance();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: VColors.prune,
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
                          colors: [VColors.pruneLight, VColors.prune],
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
                                truckLink: _truckLink,
                                truckKey: _truckKey,
                                enter: _enter,
                                ambient: _ambient,
                              ),
                            ),
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _enter,
                                // The card slides up and fades in
                                child: _FormCard(
                                  emailCtrl: _email,
                                  passwordCtrl: _password,
                                  obscure: _obscure,
                                  onToggle: () =>
                                      setState(() => _obscure = !_obscure),
                                  onSignIn: _signIn,
                                  onGoogle: _signInWithGoogle,
                                  busy: _busy,
                                  googleBusy: _googleBusy,
                                  error: _error,
                                  pendingHub: _pendingHub,
                                  onForgot: _openResetSheet,
                                  onStatus: _openStatusSheet,
                                  onRegister: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const DriverRegisterScreen(),
                                    ),
                                  ),
                                ),
                                builder: (context, child) {
                                  final v =
                                      _cardCurve.transform(_enter.value);
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

                // The truck, drawn above everything while it glides up.
                // It is glued to the empty spot in the header, so it also
                // scrolls with the header afterwards.
                Positioned(left: 0, top: 0, child: _buildTruckOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTruckOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, _) {
          // Before the entrance is measured (or after a hot reload, where
          // initState did not run) the truck simply sits in the header.
          final start = _truckStart ?? Offset.zero;

          // 0 = still at the starting spot, 1 = settled in the header
          final move = _moveCurve.transform(_enter.value);
          final startScale = _splashTruckW / _truckW;

          return CompositedTransformFollower(
            link: _truckLink,
            showWhenUnlinked: false,
            offset: start * (1 - move),
            child: Transform.scale(
              scale: 1 + (startScale - 1) * (1 - move),
              child: const SizedBox(
                width: _truckW,
                height: _truckH,
                child: _TruckPicture(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: truck spot, "Vendo Xpress", welcome text
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final LayerLink truckLink;
  final GlobalKey truckKey;
  final Animation<double> enter;
  final Animation<double> ambient;

  const _HeaderSection({
    required this.truckLink,
    required this.truckKey,
    required this.enter,
    required this.ambient,
  });

  static const _textCurve = Interval(0.55, 1.0, curve: Curves.easeOut);

  // The moving elements fade in after the truck has started to glide up
  static const _ambientFade = Interval(0.35, 0.9, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      alignment: Alignment.topCenter, // keeps the truck and texts centered
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

        // Header content (truck spot + texts)
        Padding(
          padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 36),
          child: Column(
            children: [
              // Empty spot where the truck lands (the truck itself is drawn by
              // the overlay in DriverLoginScreen)
              CompositedTransformTarget(
                link: truckLink,
                child: SizedBox(key: truckKey, width: _truckW, height: _truckH),
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
    _FloatingDot(0.10, 0.00, 1, 3.0, VColors.lin),
    _FloatingDot(0.24, 0.40, 1, 2.0, VColors.brique),
    _FloatingDot(0.38, 0.75, 2, 2.5, VColors.lin),
    _FloatingDot(0.52, 0.20, 1, 3.5, VColors.brique),
    _FloatingDot(0.66, 0.60, 1, 2.0, VColors.lin),
    _FloatingDot(0.80, 0.90, 2, 3.0, VColors.brique),
    _FloatingDot(0.92, 0.45, 1, 2.0, VColors.lin),
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
      Paint()..color = VColors.raisin.withAlpha((46 * fade).round()),
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
        ..color = VColors.lin.withAlpha(
          ((1 - p) * 55 * fade).round().clamp(0, 255),
        );
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
                    color: VColors.lin,
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
          'HAUL. TRACK. DELIVERED.',
          style: TextStyle(
            color: VColors.lin,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Welcome Back, Driver!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Review the manifest, confirm dispatch and close the trip.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 13,
            height: 1.4,
          ),
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
  final VoidCallback onSignIn;
  final VoidCallback onGoogle;
  final bool busy;
  final bool googleBusy;
  final String? error;
  final String? pendingHub;
  final VoidCallback onForgot;
  final VoidCallback onStatus;
  final VoidCallback onRegister;

  const _FormCard({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggle,
    required this.onSignIn,
    required this.onGoogle,
    required this.busy,
    required this.googleBusy,
    required this.error,
    required this.pendingHub,
    required this.onForgot,
    required this.onStatus,
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
            hint: 'driver@vendoxpress.ph',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 18),

          // Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Label('Password'),
              GestureDetector(
                onTap: busy ? null : onForgot,
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: VColors.raisin,
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
            onSubmitted: (_) => onSignIn(),
            suffix: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: VColors.muted,
                size: 22,
              ),
            ),
          ),

          // Server error
          if (error != null) ...[
            const SizedBox(height: 12),
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
                    error!,
                    style: const TextStyle(
                      color: VColors.red,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Waiting for hub approval
          if (pendingHub != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VColors.goldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: VColors.prune,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Waiting for $pendingHub approval. '
                      'You can sign in as soon as it is approved.',
                      style: const TextStyle(
                        color: VColors.ink,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Sign in button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: busy ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: VColors.prune,
                disabledBackgroundColor: VColors.prune,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: VColors.lin,
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // "or" divider
          const Row(
            children: [
              Expanded(child: Divider(thickness: 1, color: VColors.border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: VColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(thickness: 1, color: VColors.border)),
            ],
          ),
          const SizedBox(height: 20),

          // Google button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: busy || googleBusy ? null : onGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: VColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (googleBusy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: VColors.raisin,
                      ),
                    )
                  else
                    const _GoogleLogo(),
                  const SizedBox(width: 10),
                  Text(
                    googleBusy ? 'Signing in…' : 'Continue with Google',
                    style: const TextStyle(
                      color: VColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Application status
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: busy ? null : onStatus,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: VColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    size: 19,
                    color: VColors.prune,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Check application status',
                    style: TextStyle(
                      color: VColors.ink,
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
              onTap: busy ? null : onRegister,
              behavior: HitTestBehavior.opaque,
              child: RichText(
                text: const TextSpan(
                  text: 'New to Vendo Driver? ',
                  style: TextStyle(color: VColors.muted, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Register here.',
                      style: TextStyle(
                        color: VColors.brique,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Approval note
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: VColors.muted,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only approved drivers with a valid licence and an active hub can sign in. '
                  'Station Hub applications are approved by the Station Hub; Province Hub and '
                  'both-hub applications are approved by the Province Hub.',
                  style: TextStyle(
                    color: VColors.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
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

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VColors.ink,
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
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboard,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
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
      autofillHints: autofillHints,
      cursorColor: VColors.prune,
      style: const TextStyle(color: VColors.ink, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: VColors.muted, fontSize: 15),
        filled: true,
        fillColor: VColors.background,
        prefixIcon: Icon(icon, color: VColors.raisin, size: 20),
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
        border: border(VColors.border, 1.2),
        enabledBorder: border(VColors.border, 1.2),
        focusedBorder: border(VColors.prune, 1.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The truck: a box truck facing right, drawn in a 160 x 120 box.
//
// Same drawing rules as the rider picture in the Rider app (soft gold frame,
// prune/brique body, glowing headlight, spoked wheels) so both apps share one
// visual language.
// ─────────────────────────────────────────────────────────────────────────────
class _TruckPicture extends StatelessWidget {
  const _TruckPicture();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TruckPainter());
  }
}

class _TruckPainter extends CustomPainter {
  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _fill(Color c) => Paint()..color = c;

  static const _wheelAngle = 0.7;
  static const _rear = Offset(38, 84);
  static const _front = Offset(126, 84);
  static const _wheelR = 14.0;

  void _wheel(Canvas canvas, Offset c) {
    // tire + rim
    canvas.drawCircle(c, _wheelR, _stroke(const Color(0xFFEFE6F2), 5));
    canvas.drawCircle(c, _wheelR - 5.5, _stroke(VColors.lin.withAlpha(150), 1.5));

    // spokes + a marker dot
    final spoke = _stroke(VColors.lin, 2);
    for (int i = 0; i < 3; i++) {
      final a = _wheelAngle + i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * (_wheelR - 5.5);
      canvas.drawLine(c - d, c + d, spoke);
    }
    final m =
        c + Offset(math.cos(_wheelAngle), math.sin(_wheelAngle)) *
            (_wheelR - 5.5);
    canvas.drawCircle(m, 1.8, _fill(VColors.brique));
    canvas.drawCircle(c, 3.2, _fill(VColors.lin));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 120);

    const bodyLight = Color(0xFFEADFF0);
    const bodyShade = Color(0xFFCDB9D6);
    const dark = Color(0xFF1F0F21);

    // Ground line
    canvas.drawLine(
      const Offset(14, 101),
      const Offset(152, 101),
      _stroke(VColors.lin.withAlpha(70), 2),
    );

    // Headlight glow
    canvas.drawCircle(
      const Offset(148, 64),
      11,
      Paint()
        ..color = VColors.lin.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Chassis rail, behind the wheels
    canvas.drawLine(
      const Offset(20, 79),
      const Offset(144, 79),
      _stroke(VColors.lin, 4),
    );

    // Wheels next, the body covers their tops
    _wheel(canvas, _rear);
    _wheel(canvas, _front);

    // ── Cargo box ───────────────────────────────────────────────────────
    const cargo = Rect.fromLTWH(6, 26, 88, 50);
    final cargoRRect = RRect.fromRectAndRadius(
      cargo,
      const Radius.circular(6),
    );
    canvas.drawRRect(cargoRRect, _fill(bodyLight));

    // brique band along the bottom of the cargo box
    canvas.save();
    canvas.clipRRect(cargoRRect);
    canvas.drawRect(
      const Rect.fromLTWH(6, 58, 88, 18),
      _fill(VColors.brique),
    );
    canvas.restore();

    // seams between the box panels
    canvas.drawLine(
      const Offset(36, 30),
      const Offset(36, 58),
      _stroke(VColors.lin.withAlpha(110), 1.4),
    );
    canvas.drawLine(
      const Offset(66, 30),
      const Offset(66, 58),
      _stroke(VColors.lin.withAlpha(110), 1.4),
    );

    // outline on top of the fills
    canvas.drawRRect(cargoRRect, _stroke(VColors.lin, 3));

    // "V" logo on the brique band
    canvas.drawPath(
      Path()
        ..moveTo(42, 62)
        ..lineTo(50, 72)
        ..lineTo(58, 62),
      _stroke(Colors.white, 3.2),
    );

    // ── Cab ─────────────────────────────────────────────────────────────
    final cab = Path()
      ..moveTo(94, 76)
      ..lineTo(94, 46)
      ..quadraticBezierTo(94, 38, 104, 38)
      ..lineTo(126, 38)
      ..quadraticBezierTo(143, 40, 149, 56)
      ..lineTo(151, 68)
      ..quadraticBezierTo(151, 76, 143, 76)
      ..close();
    canvas.drawPath(cab, _fill(VColors.brique));

    // darker lower cab panel
    canvas.save();
    canvas.clipPath(cab);
    canvas.drawRect(
      const Rect.fromLTWH(94, 68, 58, 10),
      _fill(Colors.black.withAlpha(38)),
    );
    canvas.restore();

    // windshield
    final glass = Path()
      ..moveTo(105, 45)
      ..lineTo(124, 45)
      ..quadraticBezierTo(136, 47, 141, 62)
      ..lineTo(105, 62)
      ..close();
    canvas.drawPath(glass, _fill(dark));
    canvas.drawLine(
      const Offset(110, 50),
      const Offset(121, 50),
      _stroke(Colors.white.withAlpha(180), 1.4),
    );

    // door handle + mirror
    canvas.drawLine(
      const Offset(98, 66),
      const Offset(106, 66),
      _stroke(bodyShade, 2.4),
    );
    canvas.drawLine(
      const Offset(100, 44),
      const Offset(97, 41),
      _stroke(Colors.white.withAlpha(170), 2),
    );

    // headlight, bumper
    canvas.drawCircle(const Offset(148, 64), 4.5, _fill(Colors.white));
    canvas.drawCircle(const Offset(148, 64), 2.6, _fill(VColors.lin));
    canvas.drawLine(
      const Offset(143, 74),
      const Offset(153, 74),
      _stroke(VColors.lin, 3.5),
    );

    // ── Driver in the cab ───────────────────────────────────────────────
    // A small silhouette behind the glass, so the truck reads as "driver".
    canvas.drawCircle(
      const Offset(114, 52),
      4.6,
      _fill(bodyShade.withAlpha(150)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(107, 62)
        ..quadraticBezierTo(114, 56, 121, 62)
        ..close(),
      _fill(bodyShade.withAlpha(130)),
    );

    // mud flaps behind the rear wheel
    canvas.drawLine(
      const Offset(24, 92),
      const Offset(24, 86),
      _stroke(VColors.raisin, 3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TruckPainter oldDelegate) => false;
}

/// Looks up the application for an email and explains the decision.
class _ApplicationStatusSheet extends StatefulWidget {
  const _ApplicationStatusSheet({
    required this.initialEmail,
    required this.bottomInset,
  });

  final String initialEmail;
  final double bottomInset;

  @override
  State<_ApplicationStatusSheet> createState() => _ApplicationStatusSheetState();
}

class _ApplicationStatusSheetState extends State<_ApplicationStatusSheet> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _checked = false;
  String? _error;
  Map<String, dynamic>? _application;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email you applied with.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final application = await DriverApi.instance.applicationStatus(email);
      if (!mounted) return;
      setState(() {
        _application = application;
        _checked = true;
        if (application == null) {
          _error = 'No Transport Driver application was found for this email.';
        }
      });
    } on DriverApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Cannot reach ${DriverApi.baseUrl}. Check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _application?['status']?.toString();
    final (title, tone, message) = switch (status) {
      'approved' => (
        'Application approved',
        VColors.green,
        'Your account is active. Sign in with your email and password.',
      ),
      'rejected' => (
        'Application declined',
        VColors.red,
        (_application?['rejection_reason']?.toString().isNotEmpty ?? false)
            ? _application!['rejection_reason'].toString()
            : 'The hub declined this application. Apply again with complete documents.',
      ),
      'pending' => (
        'Waiting for approval',
        VColors.brique,
        'Still being reviewed by '
            '${(_application?['reviewing_hub'] as Map?)?['name'] ?? 'your hub'}.',
      ),
      _ => (
        'Application status',
        VColors.muted,
        'Enter the email you applied with to see where your application stands.',
      ),
    };

    final station =
        (_application?['station_hub'] as Map?)?['name']?.toString();

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Check application status',
              style: TextStyle(
                color: VColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use the email address on your Driver application.',
              style: TextStyle(color: VColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              cursorColor: VColors.prune,
              decoration: const InputDecoration(
                hintText: 'driver@vendoxpress.ph',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _check,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: VColors.lin,
                        ),
                      )
                    : const Text('Check status'),
              ),
            ),
            if (_checked && _application != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'approved'
                              ? Icons.verified_rounded
                              : status == 'rejected'
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded,
                          color: tone,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: tone,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: VColors.ink,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatusRow(
                      label: 'Applied to',
                      value:
                          (_application?['apply_label'] ?? '—').toString(),
                    ),
                    if (station != null)
                      _StatusRow(label: 'Station Hub', value: station),
                    if (_application?['approved_by'] != null)
                      _StatusRow(
                        label: 'Reviewed by',
                        value: _application!['approved_by'].toString(),
                      ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: VColors.muted, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: VColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
