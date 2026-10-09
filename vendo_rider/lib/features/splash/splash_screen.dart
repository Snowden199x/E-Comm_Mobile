import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/features/auth/screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo palette
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF412143);
  static const pruneLight = Color(0xFF55295A);
  static const brique = Color(0xFFBF5E40);
  static const lin = Color(0xFFDBC583);
  static const raisin = Color(0xFF815488);
}

// Stable pseudo-random number in [0, 1) so the city looks the same every frame.
double _hash(int n) {
  final x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

// ─────────────────────────────────────────────────────────────────────────────
// THE STORY (one animation, 0.0 → 1.0)
//
//  0.00 – 0.50  Night city. The rider speeds in from the left with the
//               headlight on. Three layers of buildings scroll at different
//               speeds (parallax), stars twinkle, wind streaks and dust fly.
//  0.28 – 0.50  Braking: brake light glows, dust skids, the bike's nose dips,
//               then the suspension bounces back and settles. A small haptic
//               "thud" is played when the bike stops.
//  0.50 – 0.78  "vendo" appears letter by letter, then a light sweeps over it.
//  0.62 – 1.00  Tagline, RIDER pill and loading bar. The engine idles with
//               a little vibration and exhaust puffs.
//  End          Fade to the login screen.
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ── Easy to tweak ──────────────────────────────────────────────────────
  static const _totalTime = Duration(milliseconds: 4200); // whole splash
  static const _riderSize = 120.0; // height of the rider + bike
  static const _riderW = _riderSize * 4 / 3; // bike + rider is wider than tall
  static const _groundOffset = 36.0; // wheel bottom is 36px below the center
  static const _flipRider = false; // set to true if the rider faces left
  // ───────────────────────────────────────────────────────────────────────

  static const _rideEnd = 0.5; // ride-in takes the first 50%
  static const _rideLinear = Interval(0.0, _rideEnd);
  static const _rideEased = Interval(0.0, _rideEnd, curve: Curves.easeOutCubic);

  late final AnimationController _ctrl;
  bool _thudded = false;

  // Nose dip when braking, then a damped bounce (suspension).
  // 0 = level, 1 = nose fully down, negative = rebound (nose up).
  static double _dip(double t) {
    if (t < 0.28) return 0;
    if (t < 0.40) {
      return Curves.easeInOut.transform(((t - 0.28) / 0.12).clamp(0.0, 1.0));
    }
    final k = t - 0.40;
    return math.exp(-k * 14) * math.cos(k * 36);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalTime);

    _ctrl.addListener(() {
      if (!_thudded && _ctrl.value >= 0.42) {
        _thudded = true;
        HapticFeedback.lightImpact();
      }
    });

    // Wait for the first frame to finish rendering before starting the animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _ctrl.forward().whenComplete(() async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A1230), _C.prune, _C.pruneLight],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final riderCy = h * 0.36;
              final groundY = riderCy + _groundOffset;

              return AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = _ctrl.value;

                  // Ride-in progress (u straight, s slows down at the end)
                  final u = _rideLinear.transform(t);
                  final s = _rideEased.transform(t);

                  // 1.0 = full speed, 0.0 = stopped
                  final speed = math.pow(1 - u, 2).toDouble();

                  final riderX = -_riderW + ((w / 2) + _riderW) * s;
                  final travel = s * 2600; // how far the "world" has moved

                  // Braking
                  final dip = _dip(t);
                  final brake =
                      const Interval(0.26, 0.34).transform(t) *
                      (1 - const Interval(0.55, 0.66).transform(t));
                  final dust =
                      (speed +
                              0.7 *
                                  brake *
                                  (1 - const Interval(0.42, 0.52).transform(t)))
                          .clamp(0.0, 1.0);

                  // Idle engine after stopping
                  final idle = const Interval(0.50, 0.58).transform(t);

                  final bob =
                      math.sin(t * math.pi * 80) * 2.5 * speed +
                      math.sin(t * math.pi * 110) * 0.6 * idle;
                  final pitch = -0.05 * speed + 0.075 * dip;

                  return Stack(
                    children: [
                      // Sky, city, road, light beam, wind, dust
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MotionPainter(
                            t: t,
                            riderX: riderX,
                            riderCy: riderCy,
                            groundY: groundY,
                            speed: speed,
                            travel: travel,
                            dust: dust,
                            idle: idle,
                          ),
                        ),
                      ),

                      // The rider (person on a motorcycle)
                      Positioned(
                        left: riderX - _riderW / 2,
                        top: riderCy - _riderSize / 2 + bob + 2 * dip,
                        width: _riderW,
                        height: _riderSize,
                        child: Transform.rotate(
                          angle: pitch,
                          alignment: const Alignment(0, 0.6), // tires
                          child: Transform.flip(
                            flipX: _flipRider,
                            child: CustomPaint(
                              painter: _RiderPainter(
                                wheelAngle: travel / 20,
                                speed: speed,
                                brake: brake,
                                phase: t,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Name, tagline, loading bar
                      Align(
                        alignment: const Alignment(0, 0.45),
                        child: _buildBrand(t),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(double t) {
    const word = 'vendo';
    final more = const Interval(0.62, 0.82, curve: Curves.easeOut).transform(t);
    final pill = const Interval(
      0.68,
      0.88,
      curve: Curves.easeOutBack,
    ).transform(t);
    final bar = const Interval(0.66, 1.0, curve: Curves.easeInOut).transform(t);
    // light sweep across the name: -0.3 → 1.3
    final sweep =
        -0.3 +
        1.6 * const Interval(0.76, 0.92, curve: Curves.easeInOut).transform(t);

    // Each letter pops up one after another
    final letters = <Widget>[];
    for (var i = 0; i < word.length; i++) {
      final start = 0.50 + i * 0.03;
      final fade = Interval(start, start + 0.16).transform(t);
      final pop = Interval(
        start,
        start + 0.16,
        curve: Curves.easeOutBack,
      ).transform(t);
      letters.add(
        Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 34 * (1 - pop)),
            child: Text(
              word[i],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Colors.white, _C.lin, Colors.white],
            stops: [
              (sweep - 0.18).clamp(0.0, 1.0),
              sweep.clamp(0.0, 1.0),
              (sweep + 0.18).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: Row(mainAxisSize: MainAxisSize.min, children: letters),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: more,
          child: Column(
            children: [
              Text(
                'BUY. SELL. DELIVERED',
                style: TextStyle(
                  color: _C.lin,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  // letters start spread out and close in as it fades in
                  letterSpacing: 3.5 + 7 * (1 - more),
                ),
              ),
              const SizedBox(height: 12),
              Transform.scale(
                scale: 0.7 + 0.3 * pill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: const Text(
                    'RIDER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Opacity(
          opacity: more,
          child: SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bar,
                minHeight: 4,
                backgroundColor: const Color(0x26FFFFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(_C.brique),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background scene: stars, moon, 3 city layers, road, headlight, wind, dust.
// `speed` goes from 1.0 (fast) to 0.0 (stopped). Motion effects are multiplied
// by it so they fade out as the rider slows down.
// ─────────────────────────────────────────────────────────────────────────────
class _Streak {
  final double x, y; // start position (fraction of screen width / height)
  final double length, speedMul, thickness, alpha;

  const _Streak(
    this.x,
    this.y,
    this.length,
    this.speedMul,
    this.thickness,
    this.alpha,
  );
}

class _MotionPainter extends CustomPainter {
  final double t, riderX, riderCy, groundY, speed, travel, dust, idle;

  _MotionPainter({
    required this.t,
    required this.riderX,
    required this.riderCy,
    required this.groundY,
    required this.speed,
    required this.travel,
    required this.dust,
    required this.idle,
  });

  static const _streaks = <_Streak>[
    _Streak(0.10, 0.18, 140, 1.4, 2.0, 0.30),
    _Streak(0.55, 0.22, 200, 1.8, 2.5, 0.35),
    _Streak(0.85, 0.27, 120, 1.2, 2.0, 0.25),
    _Streak(0.30, 0.31, 170, 1.6, 2.0, 0.30),
    _Streak(0.70, 0.42, 150, 1.5, 2.0, 0.25),
    _Streak(0.20, 0.50, 220, 2.0, 3.0, 0.35),
    _Streak(0.90, 0.55, 150, 1.3, 2.0, 0.28),
    _Streak(0.45, 0.60, 190, 1.7, 2.0, 0.30),
    _Streak(0.05, 0.66, 130, 1.5, 2.0, 0.25),
    _Streak(0.65, 0.72, 210, 1.9, 2.5, 0.32),
    _Streak(0.35, 0.80, 160, 1.4, 2.0, 0.25),
    _Streak(0.80, 0.86, 140, 1.6, 2.0, 0.22),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintSky(canvas, w, h);

    // City, far → near. Each layer scrolls at its own speed (parallax).
    _paintSkyline(
      canvas,
      w,
      scroll: travel * 0.06,
      minW: 30,
      maxW: 60,
      minH: 55,
      maxH: 120,
      color: _C.raisin.withAlpha(40),
      seed: 1000,
    );
    _paintSkyline(
      canvas,
      w,
      scroll: travel * 0.16,
      minW: 38,
      maxW: 70,
      minH: 40,
      maxH: 95,
      color: const Color(0xFF2E1530).withAlpha(170),
      seed: 2000,
      windowAlpha: 45,
    );
    _paintSkyline(
      canvas,
      w,
      scroll: travel * 0.34,
      minW: 44,
      maxW: 80,
      minH: 26,
      maxH: 68,
      color: const Color(0xFF210F23).withAlpha(210),
      seed: 3000,
      windowAlpha: 95,
    );

    _paintRoad(canvas, w);
    _paintShadow(canvas);
    _paintBeam(canvas);

    if (speed > 0.01) {
      _paintWindAcrossScreen(canvas, w, h);
      _paintWindBehindRider(canvas);
    }
    if (dust > 0.01) _paintDust(canvas);
    if (idle > 0.01) _paintExhaust(canvas);
  }

  // Twinkling stars and a glowing moon
  void _paintSky(Canvas canvas, double w, double h) {
    final star = Paint();
    for (int i = 0; i < 30; i++) {
      final x = (_hash(i * 3 + 1) * w - travel * 0.012) % w;
      final y = _hash(i * 3 + 2) * groundY * 0.6;
      final r = 0.7 + _hash(i * 3 + 3) * 1.3;
      final tw = 0.5 + 0.5 * math.sin(t * math.pi * 8 + i * 1.9);
      star.color = Colors.white.withAlpha((25 + 110 * tw).round());
      canvas.drawCircle(Offset(x, y), r, star);
    }

    final mc = Offset(w * 0.82, h * 0.11);
    canvas.drawCircle(
      mc,
      70,
      Paint()
        ..shader = RadialGradient(
          colors: [_C.lin.withAlpha(70), _C.lin.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: mc, radius: 70)),
    );
    canvas.drawCircle(mc, 20, Paint()..color = _C.lin.withAlpha(235));
    final crater = Paint()..color = _C.brique.withAlpha(45);
    canvas.drawCircle(mc + const Offset(-6, -4), 4, crater);
    canvas.drawCircle(mc + const Offset(6, 5), 3, crater);
    canvas.drawCircle(mc + const Offset(2, -9), 2, crater);
  }

  // One row of buildings, repeating forever as `scroll` grows.
  void _paintSkyline(
    Canvas canvas,
    double w, {
    required double scroll,
    required double minW,
    required double maxW,
    required double minH,
    required double maxH,
    required Color color,
    required int seed,
    int windowAlpha = 0,
  }) {
    const n = 24;
    final widths = List<double>.generate(
      n,
      (i) => minW + _hash(i + seed) * (maxW - minW),
    );
    final period = widths.fold<double>(0, (a, b) => a + b);
    final paint = Paint()..color = color;
    final win = Paint()..color = _C.lin.withAlpha(windowAlpha);

    var x = -(scroll % period);
    var i = 0;
    while (x < w) {
      final k = i % n;
      final bw = widths[k];
      final bh = minH + _hash(k + seed * 7 + 3) * (maxH - minH);
      final top = groundY + 2 - bh;
      canvas.drawRect(Rect.fromLTWH(x, top, bw + 1, bh), paint);

      if (windowAlpha > 0) {
        final cols = ((bw - 8) / 10).floor();
        final rows = ((bh - 12) / 14).floor();
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            if (_hash(k * 97 + r * 13 + c * 5 + seed) > 0.6) {
              canvas.drawRect(
                Rect.fromLTWH(x + 6 + c * 10, top + 8 + r * 14, 4, 6),
                win,
              );
            }
          }
        }
      }
      x += bw;
      i++;
    }
  }

  // Road with a soft dark ground and dashes that slide left
  void _paintRoad(Canvas canvas, double w) {
    final ground = Rect.fromLTWH(0, groundY + 2, w, 180);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withAlpha(70), Colors.black.withAlpha(0)],
        ).createShader(ground),
    );

    canvas.drawLine(
      Offset(0, groundY + 2),
      Offset(w, groundY + 2),
      Paint()
        ..color = Colors.white.withAlpha(30)
        ..strokeWidth = 2,
    );

    const dash = 26.0;
    const gap = 30.0;
    const period = dash + gap;
    final offset = travel % period;
    final dashPaint = Paint()
      ..color = _C.lin.withAlpha(70)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (double x = -offset; x < w; x += period) {
      canvas.drawLine(
        Offset(x, groundY + 18),
        Offset(x + dash, groundY + 18),
        dashPaint,
      );
    }
  }

  void _paintShadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(riderX, groundY + 4),
        width: 140,
        height: 10,
      ),
      Paint()..color = Colors.black.withAlpha(60),
    );
  }

  // Headlight cone lighting the road ahead
  void _paintBeam(Canvas canvas) {
    final hx = riderX + 44;
    final hy = riderCy - 10;
    const len = 300.0;
    final strength = 0.6 + 0.15 * math.sin(t * math.pi * 12);

    final top = hy - 34;
    final bottom = groundY + 10;
    final path = Path()
      ..moveTo(hx, hy - 3)
      ..lineTo(hx + len, top)
      ..lineTo(hx + len, bottom)
      ..lineTo(hx, hy + 3)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _C.lin.withAlpha((95 * strength).round()),
            _C.lin.withAlpha(0),
          ],
        ).createShader(Rect.fromLTWH(hx, top, len, bottom - top)),
    );
  }

  // Long streaks flying from right to left across the screen
  void _paintWindAcrossScreen(Canvas canvas, double w, double h) {
    for (final s in _streaks) {
      final length = s.length * (0.5 + speed);
      final span = w + length;
      final headX = ((s.x * w) - travel * s.speedMul) % span;
      final y = s.y * h;
      final alpha = (s.alpha * speed * 255).round().clamp(0, 255);

      final rect = Rect.fromLTWH(headX - length, y, length, 1);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withAlpha(alpha), Colors.white.withAlpha(0)],
        ).createShader(rect)
        ..strokeWidth = s.thickness
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(headX - length, y), Offset(headX, y), paint);
    }
  }

  // Short lines right behind the rider: the air being pushed back
  void _paintWindBehindRider(Canvas canvas) {
    const offsetsY = [-30.0, -12.0, 6.0, 22.0, 36.0];

    for (int i = 0; i < offsetsY.length; i++) {
      final length = (40 + (i % 3) * 22) * speed;
      if (length < 2) continue;

      final flutter = math.sin(t * math.pi * 50 + i * 1.7) * 3 * speed;
      final headX = riderX - 72 - (i % 2) * 8;
      final y = riderCy + offsetsY[i] + flutter;
      final alpha = (170 * speed).round().clamp(0, 255);

      final rect = Rect.fromLTWH(headX - length, y, length, 1);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withAlpha(0), Colors.white.withAlpha(alpha)],
        ).createShader(rect)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(headX - length, y), Offset(headX, y), paint);
    }
  }

  // Dust from the back wheel: grows and fades. Bigger when braking (skid).
  void _paintDust(Canvas canvas) {
    final paint = Paint();
    for (int i = 0; i < 6; i++) {
      final p = (t * 6 + i / 6) % 1.0;
      final cx = riderX - 44 - p * 70;
      final cy = groundY - p * 16;
      final radius = (3 + p * 9) * (0.6 + dust * 0.6);
      paint.color = Colors.white.withAlpha(
        ((1 - p) * 80 * dust).round().clamp(0, 255),
      );
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  // Little exhaust puffs while the engine idles
  void _paintExhaust(Canvas canvas) {
    final paint = Paint();
    for (int i = 0; i < 4; i++) {
      final p = (t * 2.2 + i / 4) % 1.0;
      final cx = riderX - 50 - p * 26;
      final cy = riderCy + 22 - p * 20;
      final radius = 2.5 + p * 7;
      paint.color = Colors.white.withAlpha(
        ((1 - p) * 55 * idle).round().clamp(0, 255),
      );
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MotionPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Person on a motorcycle with a delivery box, drawn in a 160 x 120 box and
// scaled to fit. Faces right.
//   wheelAngle: spins the wheels
//   speed:      1 fast → 0 stopped (wheel blur, scarf flutter)
//   brake:      0 → 1 brake light
//   phase:      animation time (for the scarf)
// ─────────────────────────────────────────────────────────────────────────────
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

  // Wheel radius is 20, so with center y = 76 the tire touches y = 96,
  // which is exactly 36px below the box center (_groundOffset).
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
    // leg (outlined so it stands out from the dark city)
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
