import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/auth/screens/login_screen.dart';
import 'package:vendo_buyer/features/home/screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Vendo splash: a person walks up to a vending machine, inserts
//  a coin, the Vendo logo drops out, they grab it and throw it
//  at the camera, and the logo + brand reveal.
//  Everything is drawn with CustomPainter (no extra packages);
//  only the logo is the real asset image.
// ─────────────────────────────────────────────────────────────

const _orange = Color(0xFFE8873A);
const _purple = Color(0xFF3B1F52);
const _purpleDark = Color(0xFF2A1440);

// Moments in the timeline (0..1 of the total duration).
const _tGrab = 0.69; // person starts picking up the logo
const _tFlight = 0.81; // logo leaves the hand

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 8200);

  late final AnimationController _ctrl; // main story timeline
  late final AnimationController _loop; // gentle looping pulse / float

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _total);
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _ctrl.forward().whenComplete(_goNext);
  }

  Future<void> _goNext() async {
    // A stored buyer token opens the storefront; otherwise start at sign-in.
    final signedIn = await BuyerApi.instance.hasToken();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            signedIn ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _purpleDark,
      body: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _loop]),
            builder: (context, _) => _buildScene(size),
          );
        },
      ),
    );
  }

  Widget _buildScene(Size size) {
    final g = _Geo(size);
    final tl = _TL(_ctrl.value);
    final pulse = (math.sin(_loop.value * math.pi * 2) + 1) / 2;
    final pose = _Pose(g, tl);

    // ── Logo: where is it, how big, how rotated? ─────────────
    final carryOff = Offset(-0.01 * g.pH, -0.035 * g.pH);

    // 1) sitting on the shelf, then dropping into the tray (with bounce)
    var pos = g.shelfLogo + Offset(tl.shake, 0);
    pos = Offset.lerp(pos, g.trayLogo + Offset(tl.shake, 0), tl.drop)!;
    var logoSize = g.logoSize;
    var rotZ = math.sin(tl.dropRaw * math.pi) * 0.35;
    var rotY = 0.0;

    // 2) picked up and carried in the person's hand
    if (tl.t >= _tGrab) {
      pos = Offset.lerp(g.trayLogo, pose.frontHand + carryOff, tl.slide)!;
      logoSize = g.logoSize * (1 + 0.25 * tl.slide);
      rotZ = 0;
    }

    // 3) thrown toward the camera, flips, lands in the centre
    if (tl.t > _tFlight) {
      final release = g.releasePoint + carryOff;
      pos = Offset.lerp(release, g.finalCenter, tl.flightPos)!;
      pos += Offset(0, -math.sin(tl.flightPos * math.pi) * size.height * 0.05);
      var s = lerpDouble(g.logoSize * 1.25, g.finalSize * 1.45, tl.grow)!;
      s = lerpDouble(s, g.finalSize, tl.settle)!;
      logoSize = s;
      rotY = tl.spin * math.pi * 2;
      rotZ = -math.sin(tl.spin * math.pi) * 0.4;
      // gentle float once it has landed
      pos += Offset(0, math.sin(_loop.value * math.pi * 2) * 4 * tl.reveal);
    }

    final groupOpacity = (tl.intro * (1 - tl.exit)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background, spotlight, floor
        SizedBox.expand(
          child: CustomPaint(painter: _BgPainter(g, tl)),
        ),

        // Machine + person (fade out when the logo takes over)
        if (groupOpacity > 0)
          Opacity(
            opacity: groupOpacity,
            child: Transform.translate(
              offset: Offset(0, (1 - tl.intro) * 30),
              child: Transform.scale(
                scale: 1 - 0.06 * tl.exit,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(tl.shake, 0),
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: _MachinePainter(g, tl, pulse),
                        ),
                      ),
                    ),
                    SizedBox.expand(
                      child: CustomPaint(
                        painter: _PersonPainter(g, tl, pose),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Glow, shockwave rings and sparkles (behind the logo)
        SizedBox.expand(
          child: CustomPaint(
            painter: _FxPainter(
              g.finalCenter,
              g.finalSize,
              tl.glow,
              tl.ring,
              pulse,
            ),
          ),
        ),

        // Brand name + tagline
        Positioned(
          left: 0,
          right: 0,
          top: g.finalCenter.dy + g.finalSize / 2 + 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: tl.brand,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - tl.brand)),
                  child: Text(
                    'vendo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: lerpDouble(12, 3, tl.brand)!,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: tl.tag,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - tl.tag)),
                  child: const Text(
                    'BUY. SELL. DELIVERED',
                    style: TextStyle(
                      color: _orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Spinner
        Positioned(
          left: 0,
          right: 0,
          bottom: size.height * 0.08,
          child: Center(
            child: Opacity(
              opacity: tl.tag,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_orange),
                ),
              ),
            ),
          ),
        ),

        // The Vendo logo (real asset) – always on top
        Positioned(
          left: pos.dx - logoSize / 2,
          top: pos.dy - logoSize / 2,
          width: logoSize,
          height: logoSize,
          child: Opacity(
            opacity: tl.intro,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(rotY)
                ..rotateZ(rotZ),
              child: Image.asset(
                'assets/images/vendo_app_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Timeline – every animation phase as a 0..1 value
// ═════════════════════════════════════════════════════════════
class _TL {
  const _TL(this.t);
  final double t;

  double _s(double a, double b, [Curve c = Curves.linear]) =>
      c.transform(((t - a) / (b - a)).clamp(0.0, 1.0).toDouble());

  double get intro => _s(0.00, 0.10, Curves.easeOutCubic); // machine appears
  double get walk => _s(0.06, 0.26, Curves.easeOut); // person walks in
  double get raise => _s(0.26, 0.35, Curves.easeInOut); // arm to coin slot
  double get insert => _s(0.35, 0.41, Curves.easeIn); // coin goes in
  double get buzz => _s(0.41, 0.52); // machine shakes
  double get retract => _s(0.43, 0.53, Curves.easeInOut); // arm back down
  double get dropRaw => _s(0.50, 0.62); // logo falls
  double get drop => _s(0.50, 0.62, Curves.bounceOut);
  double get landGlow => _s(0.55, 0.62) * (1 - _s(0.62, 0.70));
  double get reach => _s(0.62, 0.69, Curves.easeInOut); // lean to the tray
  double get grab => _s(_tGrab, 0.75, Curves.easeInOut); // wind-up
  double get slide => _s(_tGrab, 0.715, Curves.easeOut); // logo -> hand
  double get thr => _s(0.75, _tFlight, Curves.easeIn); // the throw
  double get recover => _s(0.82, 0.90, Curves.easeInOut);
  double get flightPos => _s(_tFlight, 0.90, Curves.easeOut);
  double get grow => _s(_tFlight, 0.89, Curves.easeIn);
  double get settle => _s(0.89, 0.95, Curves.easeOut);
  double get spin => _s(_tFlight, 0.92, Curves.easeOut);
  double get exit => _s(0.83, 0.93, Curves.easeIn); // machine fades away
  double get glow => _s(0.84, 0.95);
  double get ring => _s(0.90, 1.00, Curves.easeOut);
  double get brand => _s(0.92, 0.99, Curves.easeOut);
  double get tag => _s(0.95, 1.00, Curves.easeOut);
  double get reveal => _s(0.93, 1.00);

  double get shake {
    final b = buzz;
    return (b > 0 && b < 1) ? math.sin(b * math.pi * 14) * 2.6 * (1 - b) : 0.0;
  }
}

// ═════════════════════════════════════════════════════════════
//  Geometry – all positions derived from the screen size
// ═════════════════════════════════════════════════════════════
class _Geo {
  _Geo(this.size);
  final Size size;

  late final double mW =
      math.min(math.min(size.width * 0.58, 260.0), size.height * 0.36);
  late final double mH = mW * 1.6;
  late final double mLeft = size.width * 0.40 - mW / 2;
  late final double mTop = (size.height - mH) / 2 - size.height * 0.03;
  late final double floorY = mTop + mH;

  Rect get machine => Rect.fromLTWH(mLeft, mTop, mW, mH);
  Rect get window =>
      Rect.fromLTWH(mLeft + 0.07 * mW, mTop + 0.14 * mH, 0.62 * mW, 0.52 * mH);
  Rect get tray =>
      Rect.fromLTWH(mLeft + 0.07 * mW, mTop + 0.70 * mH, 0.62 * mW, 0.13 * mH);
  Offset get slot => Offset(mLeft + 0.835 * mW, mTop + 0.52 * mH);

  double get logoSize => mW * 0.19;
  double get shelf1Y => window.top + 0.46 * window.height;
  Offset get shelfLogo => Offset(window.center.dx, shelf1Y - logoSize / 2);
  Offset get trayLogo =>
      Offset(tray.center.dx, tray.top + tray.height * 0.42);
  Offset get trayGrab =>
      Offset(tray.right - 0.06 * tray.width, tray.center.dy);

  // person
  double get pH => mH * 0.7;
  double get stopX => mLeft + mW + pH * 0.12;
  double get startX => size.width + pH * 0.35;
  Offset get restShoulder => Offset(stopX, floorY - 0.74 * pH);
  Offset get releasePoint =>
      restShoulder + Offset(-0.30 * pH, -0.22 * pH);

  // final logo
  Offset get finalCenter => Offset(size.width / 2, size.height * 0.36);
  double get finalSize => math.min(size.width * 0.46, 190.0);
}

// ═════════════════════════════════════════════════════════════
//  Person pose (walk cycle, leaning, 2-bone arm IK)
// ═════════════════════════════════════════════════════════════
class _Limb {
  const _Limb(this.elbow, this.hand);
  final Offset elbow;
  final Offset hand;
}

_Limb _solveArm(Offset s, Offset target, double l) {
  var d = target - s;
  var dist = d.distance;
  final maxD = 2 * l * 0.995;
  if (dist > maxD) {
    d = d / dist * maxD;
    dist = maxD;
  }
  if (dist < 0.01) return _Limb(s + Offset(0, l), s);
  final theta = math.acos((dist / 2) / l);
  final elbow = s + Offset.fromDirection(d.direction - theta, l);
  return _Limb(elbow, s + d);
}

class _Pose {
  _Pose(this.g, this.tl) {
    final pH = g.pH;
    final w = tl.walk;
    x = lerpDouble(g.startX, g.stopX, w)!;
    final phase = w * math.pi * 2 * 3.5;
    amp = 1 - Curves.easeIn.transform(w);
    swing = math.sin(phase);
    final bob = math.sin(phase * 2).abs() * 0.012 * pH * amp;
    lean = tl.reach * (1 - tl.grab);

    shoulder = Offset(
      x - 0.15 * pH * lean,
      g.floorY - 0.74 * pH + 0.13 * pH * lean - bob,
    );
    hip = Offset(x, g.floorY - 0.40 * pH - bob);

    // Where the front hand wants to be, phase by phase.
    final idle = shoulder + Offset(-0.03 * pH + swing * 0.10 * pH * amp, 0.36 * pH);
    var h = idle;
    h = Offset.lerp(h, g.slot, tl.raise)!; // up to the coin slot
    h = Offset.lerp(h, idle, tl.retract)!; // back down
    h = Offset.lerp(h, g.trayGrab, tl.reach)!; // reach into the tray
    h = Offset.lerp(h, shoulder + Offset(0.20 * pH, -0.05 * pH), tl.grab)!; // wind-up
    h = Offset.lerp(h, g.releasePoint, tl.thr)!; // throw!
    h = Offset.lerp(h, idle, tl.recover)!; // relax

    frontRoot = shoulder + Offset(-0.015 * pH, 0.01 * pH);
    final fr = _solveArm(frontRoot, h, 0.2 * pH);
    frontElbow = fr.elbow;
    frontHand = fr.hand;

    backRoot = shoulder + Offset(0.045 * pH, 0);
    final br = _solveArm(
      backRoot,
      backRoot + Offset(0.03 * pH - swing * 0.10 * pH * amp, 0.36 * pH),
      0.2 * pH,
    );
    backElbow = br.elbow;
    backHand = br.hand;

    for (final i in [-1, 1]) {
      final lift = math.max(0.0, math.sin(phase + (i > 0 ? 0 : math.pi))) *
          0.035 *
          pH *
          amp;
      final foot = Offset(
        x + 0.025 * pH * i + swing * i * 0.11 * pH * amp,
        g.floorY - lift,
      );
      final top = hip + Offset(0.025 * pH * i, 0);
      final knee = Offset.lerp(top, foot, 0.5)! + Offset(-0.025 * pH, 0);
      legs.add([top, knee, foot]);
    }
  }

  final _Geo g;
  final _TL tl;

  late final double x;
  late final double amp;
  late final double swing;
  late final double lean;
  late final Offset shoulder;
  late final Offset hip;
  late final Offset frontRoot;
  late final Offset frontElbow;
  late final Offset frontHand;
  late final Offset backRoot;
  late final Offset backElbow;
  late final Offset backHand;
  final List<List<Offset>> legs = [];
}

// ═════════════════════════════════════════════════════════════
//  Helpers
// ═════════════════════════════════════════════════════════════
void _drawText(
  Canvas c,
  String s,
  Offset center, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w700,
  double spacing = 0,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void _star(Canvas c, Offset p, double r, Paint paint) {
  final path = Path()
    ..moveTo(p.dx, p.dy - r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
    ..close();
  c.drawPath(path, paint);
}

// ═════════════════════════════════════════════════════════════
//  Background
// ═════════════════════════════════════════════════════════════
class _BgPainter extends CustomPainter {
  _BgPainter(this.g, this.tl);
  final _Geo g;
  final _TL tl;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purple, _purpleDark],
        ).createShader(rect),
    );

    final fade = tl.intro * (1 - tl.exit);

    // warm spotlight behind the machine
    final c = Offset(g.machine.center.dx, g.mTop + g.mH * 0.45);
    final r = g.mH * 0.95;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _orange.withOpacity(0.16 * fade),
            _orange.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // floor
    final floor = Rect.fromLTRB(0, g.floorY, size.width, size.height);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.10 * fade),
            Colors.white.withOpacity(0),
          ],
        ).createShader(floor),
    );
    canvas.drawLine(
      Offset(0, g.floorY),
      Offset(size.width, g.floorY),
      Paint()
        ..color = Colors.white.withOpacity(0.12 * fade)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═════════════════════════════════════════════════════════════
//  Vending machine
// ═════════════════════════════════════════════════════════════
class _MachinePainter extends CustomPainter {
  _MachinePainter(this.g, this.tl, this.pulse);
  final _Geo g;
  final _TL tl;
  final double pulse;

  static const _decoy = [
    Color(0xFF7BC4B0),
    Color(0xFFE05A6D),
    Color(0xFF6C8EEF),
    Color(0xFFF2C14E),
    Color(0xFF9B6BDB),
  ];

  void _item(Canvas c, Rect r, Color col) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
    c.drawRRect(rr, Paint()..color = col);
    c.save();
    c.clipRRect(rr);
    c.drawRect(
      Rect.fromLTWH(r.left, r.top + r.height * 0.35, r.width, r.height * 0.3),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = g.machine;
    final mW = g.mW;
    final mH = g.mH;

    // floor shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(m.center.dx, g.floorY + 3),
        width: mW * 1.2,
        height: mW * 0.12,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // body
    final body = RRect.fromRectAndRadius(m, Radius.circular(mW * 0.07));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A4590), Color(0xFF38204F)],
        ).createShader(m),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.2),
    );

    // neon sign
    final sign = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        m.left + 0.07 * mW,
        m.top + 0.035 * mH,
        0.86 * mW,
        0.075 * mH,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(sign, Paint()..color = const Color(0xFF1E0F2E));
    canvas.drawRRect(
      sign,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _orange.withOpacity(0.25 + 0.25 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      sign,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _orange.withOpacity(0.6 + 0.4 * pulse),
    );
    _drawText(
      canvas,
      'vendo',
      sign.outerRect.center,
      size: mH * 0.045,
      color: Colors.white,
      weight: FontWeight.w900,
      spacing: 2,
    );

    // ── glass window ──────────────────────────────
    final w = g.window;
    final win = RRect.fromRectAndRadius(w, const Radius.circular(10));
    canvas.drawRRect(
      win,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2354), Color(0xFF150A22)],
        ).createShader(w),
    );

    canvas.save();
    canvas.clipRRect(win);

    final shelf1 = g.shelf1Y;
    final shelf2 = w.top + 0.74 * w.height;
    final shelfPaint = Paint()..color = const Color(0xFF7A58A0);

    // shelf 1 (the Vendo logo sits in the middle gap)
    canvas.drawRect(Rect.fromLTRB(w.left, shelf1, w.right, shelf1 + 3), shelfPaint);
    _item(canvas, Rect.fromLTWH(w.left + 0.07 * w.width, shelf1 - 0.2 * w.height, 0.21 * w.width, 0.2 * w.height), _decoy[0]);
    _item(canvas, Rect.fromLTWH(w.left + 0.72 * w.width, shelf1 - 0.2 * w.height, 0.21 * w.width, 0.2 * w.height), _decoy[1]);

    // shelf 2 (gap in the centre so the logo can fall through)
    canvas.drawRect(Rect.fromLTRB(w.left, shelf2, w.left + 0.30 * w.width, shelf2 + 3), shelfPaint);
    canvas.drawRect(Rect.fromLTRB(w.left + 0.70 * w.width, shelf2, w.right, shelf2 + 3), shelfPaint);
    _item(canvas, Rect.fromLTWH(w.left + 0.04 * w.width, shelf2 - 0.16 * w.height, 0.11 * w.width, 0.16 * w.height), _decoy[2]);
    _item(canvas, Rect.fromLTWH(w.left + 0.17 * w.width, shelf2 - 0.16 * w.height, 0.11 * w.width, 0.16 * w.height), _decoy[3]);
    _item(canvas, Rect.fromLTWH(w.left + 0.72 * w.width, shelf2 - 0.16 * w.height, 0.11 * w.width, 0.16 * w.height), _decoy[4]);
    _item(canvas, Rect.fromLTWH(w.left + 0.85 * w.width, shelf2 - 0.16 * w.height, 0.11 * w.width, 0.16 * w.height), _decoy[0]);

    // lights flicker while the machine "works"
    final b = tl.buzz;
    if (b > 0 && b < 1) {
      canvas.drawRRect(
        win,
        Paint()..color = _orange.withOpacity(0.10 * (math.sin(b * 30) + 1) / 2),
      );
    }

    // glass reflection
    final refl = Path()
      ..moveTo(w.left + 0.10 * w.width, w.top)
      ..lineTo(w.left + 0.38 * w.width, w.top)
      ..lineTo(w.left + 0.14 * w.width, w.bottom)
      ..lineTo(w.left - 0.14 * w.width, w.bottom)
      ..close();
    canvas.drawPath(refl, Paint()..color = Colors.white.withOpacity(0.07));
    canvas.restore();

    canvas.drawRRect(
      win,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF8A66B0).withOpacity(0.9),
    );

    // ── side panel ────────────────────────────────
    final px = m.left + 0.73 * mW;
    final pw = 0.2 * mW;

    final disp = RRect.fromRectAndRadius(
      Rect.fromLTWH(px, m.top + 0.15 * mH, pw, 0.055 * mH),
      const Radius.circular(4),
    );
    canvas.drawRRect(disp, Paint()..color = const Color(0xFF0E0616));
    final ok = tl.insert >= 1;
    _drawText(
      canvas,
      ok ? 'OK' : '--',
      disp.outerRect.center,
      size: mH * 0.03,
      color: _orange.withOpacity(ok ? 1.0 : 0.35 + 0.65 * pulse),
      spacing: 1.5,
    );

    // keypad
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final pressed = ok && tl.dropRaw == 0 && r == 1 && c == 1;
        final key = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            px + c * (pw / 3),
            m.top + 0.24 * mH + r * 0.05 * mH,
            pw / 3 - 3,
            0.04 * mH,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          key,
          Paint()..color = pressed ? _orange : const Color(0xFF55356F),
        );
      }
    }

    // coin slot (glows when the hand arrives)
    final glow = (tl.raise * (1 - tl.retract)).clamp(0.0, 1.0);
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(center: g.slot, width: 0.18 * mW, height: 0.13 * mH),
      const Radius.circular(6),
    );
    canvas.drawRRect(plate, Paint()..color = const Color(0xFF241236));
    if (glow > 0) {
      canvas.drawRRect(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _orange.withOpacity(0.5 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _orange.withOpacity(0.35 + 0.65 * glow),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: g.slot, width: 0.026 * mW, height: 0.07 * mH),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black,
    );
    _drawText(
      canvas,
      'COIN',
      Offset(g.slot.dx, g.slot.dy + 0.095 * mH),
      size: mH * 0.022,
      color: Colors.white.withOpacity(0.55),
      spacing: 1,
    );

    // ── dispenser tray ────────────────────────────
    final tr = RRect.fromRectAndRadius(g.tray, const Radius.circular(8));
    canvas.drawRRect(tr, Paint()..color = const Color(0xFF0C0514));
    if (tl.landGlow > 0) {
      canvas.drawRRect(
        tr,
        Paint()..color = _orange.withOpacity(0.35 * tl.landGlow),
      );
    }
    canvas.drawRRect(
      tr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8A66B0).withOpacity(0.8),
    );
    canvas.drawLine(
      Offset(g.tray.left + 6, g.tray.top + 5),
      Offset(g.tray.right - 6, g.tray.top + 5),
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..strokeWidth = 2,
    );

    // ── kick plate with vents ─────────────────────
    final kick = Rect.fromLTWH(
      m.left + 0.07 * mW,
      m.top + 0.87 * mH,
      0.86 * mW,
      0.09 * mH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(kick, const Radius.circular(5)),
      Paint()..color = const Color(0xFF241236),
    );
    for (var i = 1; i <= 3; i++) {
      final y = kick.top + kick.height * i / 4;
      canvas.drawLine(
        Offset(kick.left + 8, y),
        Offset(kick.right - 8, y),
        Paint()
          ..color = Colors.white.withOpacity(0.10)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═════════════════════════════════════════════════════════════
//  Person
// ═════════════════════════════════════════════════════════════
class _PersonPainter extends CustomPainter {
  _PersonPainter(this.g, this.tl, this.pose);
  final _Geo g;
  final _TL tl;
  final _Pose pose;

  static const _skin = Color(0xFFF2C9A0);
  static const _hair = Color(0xFF5A3825);
  static const _jeans = Color(0xFF4B5D8A);
  static const _hoodie = _orange;
  static const _hoodieDark = Color(0xFFB8621F);

  void _limb(Canvas c, Offset a, Offset b, Offset d, double w, Color col,
      {Color? outline}) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy);
    if (outline != null) {
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = w + 3
          ..color = outline,
      );
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w
        ..color = col,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (tl.walk <= 0) return;
    final pH = g.pH;
    final p = pose;

    // ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.x, g.floorY + 2),
        width: pH * 0.4,
        height: pH * 0.05,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // back arm
    _limb(canvas, p.backRoot, p.backElbow, p.backHand, pH * 0.07, _hoodieDark);
    canvas.drawCircle(p.backHand, pH * 0.036, Paint()..color = _skin);

    // legs + shoes
    for (final leg in p.legs) {
      _limb(canvas, leg[0], leg[1], leg[2], pH * 0.085, _jeans);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: leg[2] + Offset(-0.03 * pH, -0.02 * pH),
            width: 0.13 * pH,
            height: 0.055 * pH,
          ),
          Radius.circular(pH * 0.025),
        ),
        Paint()..color = Colors.white,
      );
    }

    // torso (hoodie)
    canvas.drawLine(
      p.hip,
      p.shoulder,
      Paint()
        ..color = _hoodie
        ..strokeWidth = 0.21 * pH
        ..strokeCap = StrokeCap.round,
    );

    // head
    final head = p.shoulder + Offset(-0.02 * pH, -0.17 * pH);
    final hr = 0.1 * pH;
    canvas.drawCircle(head, hr, Paint()..color = _skin);
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: hr * 1.04),
      -math.pi * 0.95,
      math.pi * 1.3,
      true,
      Paint()..color = _hair,
    );
    canvas.drawCircle(
      head + Offset(-0.045 * pH, 0.008 * pH),
      0.011 * pH,
      Paint()..color = const Color(0xFF2A1B1B),
    );

    // front arm + hand
    _limb(canvas, p.frontRoot, p.frontElbow, p.frontHand, pH * 0.075, _hoodie,
        outline: _hoodieDark);
    canvas.drawCircle(p.frontHand, pH * 0.04, Paint()..color = _skin);

    // the coin
    if (tl.insert < 1) {
      final off = Offset(-0.03 * pH, -0.015 * pH) * (1 - tl.insert);
      final c = p.frontHand + off;
      final rr = 0.034 * pH;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1 - 0.85 * tl.insert, 1);
      canvas.drawCircle(Offset.zero, rr, Paint()..color = const Color(0xFFFFC94A));
      canvas.drawCircle(
        Offset.zero,
        rr * 0.65,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFE09A1A),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═════════════════════════════════════════════════════════════
//  Reveal effects: glow, shockwave rings, sparkles
// ═════════════════════════════════════════════════════════════
class _FxPainter extends CustomPainter {
  _FxPainter(this.center, this.logo, this.glow, this.ring, this.pulse);
  final Offset center;
  final double logo;
  final double glow;
  final double ring;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow > 0) {
      final r = logo * 1.15 * (0.9 + 0.1 * pulse);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _orange.withOpacity(0.38 * glow),
              _orange.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    if (ring <= 0 || ring >= 1) return;

    // two expanding rings
    for (var i = 0; i < 2; i++) {
      final p = ((ring - i * 0.2) / (1 - i * 0.2)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        center,
        logo * (0.55 + 1.1 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 3 * (1 - p)
          ..color = _orange.withOpacity(0.6 * (1 - p)),
      );
    }

    // sparkles flying outward
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n + 0.3;
      final dist = logo * (0.6 + 0.9 * ring) * (0.8 + 0.4 * ((i % 3) / 2));
      final pt = center + Offset.fromDirection(a, dist);
      final r = (1 - ring) * (i.isEven ? 6 : 4) + 1;
      _star(
        canvas,
        pt,
        r,
        Paint()
          ..color = (i.isEven ? Colors.white : _orange)
              .withOpacity((1 - ring).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}