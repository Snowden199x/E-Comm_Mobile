import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo "Warm Courier Kinetic" palette (same as Home and Deliveries)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF3C2143);
  static const pruneDark = Color(0xFF22102A);
  static const pruneDeep = Color(0xFF1A0D2E);
  static const brique = Color(0xFFC85A32);
  static const glow = Color(0xFFFE8357);
  static const lin = Color(0xFFFFDEAD);
  static const lilac = Color(0xFFCFC3CC);
  static const ink = Color(0xFF1C1C19);
  static const muted = Color(0xFF7D747D);
  static const cell = Color(0xFFF6F3EE);
  static const border = Color(0xFFEDE6DD);
}

/// Stand-alone scanner opened from the Home "Assign Parcel to Me" button.
///
/// Scans any QR or Code-128 barcode and pops with the raw value.
/// The caller decides what to do with it (navigate to Deliveries, etc.).
class ParcelScannerScreen extends StatefulWidget {
  const ParcelScannerScreen({super.key, this.expectedCode});

  /// When set, only a code with exactly this value is accepted. The parcel
  /// page uses it so the rider cannot scan a different parcel's label.
  final String? expectedCode;

  @override
  State<ParcelScannerScreen> createState() => _ParcelScannerScreenState();
}

class _ParcelScannerScreenState extends State<ParcelScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController? _camera =
      defaultTargetPlatform == TargetPlatform.linux
      ? null
      : MobileScannerController(
          formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
        );

  bool _found = false;
  Process? _linuxProc;
  StreamSubscription<String>? _linuxSub;
  String _message = 'Point camera at a parcel QR or barcode.';
  String _hint = 'Align barcode or QR code inside the box';

  // Drives the scanner animations (laser sweep + corner glow), loops forever.
  late final AnimationController _fx;

  @override
  void initState() {
    super.initState();
    _fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _startLinux();
    }
  }

  Future<void> _startLinux() async {
    try {
      final proc = await Process.start('zbarcam', [
        '--raw',
        '--set',
        'qrcode.enable=1',
        '--set',
        'code128.enable=1',
      ]);
      if (!mounted) {
        proc.kill();
        return;
      }
      _linuxProc = proc;
      setState(
        () => _message =
            'Point the laptop camera at the barcode. The preview opens in a separate window.',
      );
      _linuxSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((code) {
            if (_found || !mounted) return;
            if (code.trim().isNotEmpty) _accept(code.trim());
          });
    } on ProcessException {
      if (mounted) {
        setState(
          () => _message =
              'Linux camera reader missing. Install zbar package and retry.',
        );
      }
    }
  }

  /// Pops with [raw] when it is the code this screen is waiting for;
  /// otherwise shows which label to scan and keeps the camera running.
  bool _accept(String raw) {
    if (_found) return false;
    final expected = widget.expectedCode;
    if (expected != null && raw != expected) {
      if (mounted) {
        setState(
          () => _hint = 'That label is a different parcel. Scan $expected.',
        );
      }
      return false;
    }
    _found = true;
    Navigator.pop(context, raw);
    return true;
  }

  @override
  void dispose() {
    _fx.dispose();
    _linuxSub?.cancel();
    _linuxProc?.kill();
    if (_camera != null) unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.pruneDark,
        body: Stack(
          children: [
            // Dark plum backdrop with a soft glow at the top
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2E1635), _C.pruneDark, Color(0xFF170A1C)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 360,
                    height: 240,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0x803C2143), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildHintPill(),
                  // ── Camera viewfinder ────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final side = math.min(
                              math.min(box.maxWidth, box.maxHeight),
                              340.0,
                            );
                            return SizedBox(
                              width: side,
                              height: side,
                              child: _buildViewfinder(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  _buildInstructionCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: back button, title, torch ────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: Material(
              color: _C.prune,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan Parcel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _fx,
                      builder: (context, _) {
                        // 2 pulses per 4.8s loop → seamless
                        final pulse =
                            0.5 + 0.5 * math.sin(_fx.value * math.pi * 2 * 2);
                        return Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _C.glow.withAlpha((130 + pulse * 125).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _C.glow.withAlpha((pulse * 110).round()),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'QR & CODE 128',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.lilac,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_camera != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Toggle flashlight',
              child: Material(
                color: _C.prune,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _camera.toggleTorch(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.flashlight_on_outlined,
                      color: Color(0xFFE0BAE5),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Small pill above the viewfinder
  Widget _buildHintPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC3C2143),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33CFC3CC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner_rounded, color: _C.glow, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF3F0EB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Viewfinder: live camera in a rounded frame + glowing overlay ──
  Widget _buildViewfinder() {
    final isLinux = defaultTargetPlatform == TargetPlatform.linux;

    return AnimatedBuilder(
      animation: _fx,
      builder: (context, child) {
        final pulse = 0.5 + 0.5 * math.sin(_fx.value * math.pi * 2 * 2);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x26CFC3CC)),
            boxShadow: [
              BoxShadow(
                color: _C.glow.withAlpha((30 + pulse * 40).round()),
                blurRadius: 24 + pulse * 12,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                // Soft vignette so the camera blends into the plum frame
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0x00000000), Color(0x59170A1C)],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Corner brackets + lens crosshair
                IgnorePointer(
                  child: CustomPaint(painter: _ScanOverlayPainter(pulse)),
                ),
                // Laser sweep (ping-pong, 2.4s each way)
                IgnorePointer(child: _buildLaser(_fx.value)),
              ],
            ),
          ),
        );
      },
      // The camera itself is built once and is not rebuilt every frame.
      child: isLinux
          ? Container(
              color: const Color(0xFF170A1C),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(28),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          : MobileScanner(
              controller: _camera!,
              onDetect: (capture) {
                if (_found) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue?.trim();
                  if (raw != null && raw.isNotEmpty && _accept(raw)) return;
                }
              },
            ),
    );
  }

  Widget _buildLaser(double t) {
    // triangle wave 0 → 1 → 0, eased
    final tri = t < 0.5 ? t * 2 : (1 - t) * 2;
    final p = Curves.easeInOut.transform(tri);
    final edge = (math.sin(tri * math.pi)).clamp(0.0, 1.0); // fades at the ends
    final opacity = 0.35 + 0.65 * edge;

    return LayoutBuilder(
      builder: (context, box) {
        final top = box.maxHeight * 0.03 + p * box.maxHeight * 0.93;
        return Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: Column(
                  children: [
                    Container(
                      height: 3,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FE8357),
                            _C.glow,
                            Color(0x00FE8357),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(color: Color(0x99FE8357), blurRadius: 12),
                        ],
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: 0.75,
                      child: Container(
                        height: 32,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x33FE8357), Color(0x00FE8357)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Instruction card ─────────────────────────────────────────────
  Widget _buildInstructionCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0x1AC85A32),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _C.brique,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SCAN PARCEL',
                  style: TextStyle(
                    color: _C.brique,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.cell,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _fx,
                      builder: (context, _) {
                        final pulse =
                            0.5 + 0.5 * math.sin(_fx.value * math.pi * 2 * 2);
                        return Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _C.glow.withAlpha((110 + pulse * 145).round()),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Auto scan',
                      style: TextStyle(
                        color: _C.prune,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EDE9)),
          const SizedBox(height: 14),
          const Text(
            'Align the QR code or barcode inside the frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.expectedCode == null
                ? 'Scanning will happen automatically'
                : 'Scanning for ${widget.expectedCode}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _FormatChip(icon: Icons.qr_code_2_rounded, label: 'QR code'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _FormatChip(icon: Icons.view_week_rounded, label: 'Code 128'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FormatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _C.cell,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _C.prune, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _C.prune,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glowing corner brackets + faint lens crosshair
// `pulse` goes 0 → 1 → 0 and drives the glow strength.
// ─────────────────────────────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  final double pulse;

  _ScanOverlayPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 16.0;
    const r = 14.0; // corner roundness
    const len = 34.0; // arm length

    final l = inset;
    final t = inset;
    final rr = size.width - inset;
    final bb = size.height - inset;

    final path = Path()
      // Top-left
      ..moveTo(l, t + len)
      ..lineTo(l, t + r)
      ..arcTo(Rect.fromLTWH(l, t, r * 2, r * 2), math.pi, math.pi / 2, false)
      ..lineTo(l + len, t)
      // Top-right
      ..moveTo(rr - len, t)
      ..lineTo(rr - r, t)
      ..arcTo(Rect.fromLTWH(rr - r * 2, t, r * 2, r * 2), -math.pi / 2,
          math.pi / 2, false)
      ..lineTo(rr, t + len)
      // Bottom-right
      ..moveTo(rr, bb - len)
      ..lineTo(rr, bb - r)
      ..arcTo(Rect.fromLTWH(rr - r * 2, bb - r * 2, r * 2, r * 2), 0,
          math.pi / 2, false)
      ..lineTo(rr - len, bb)
      // Bottom-left
      ..moveTo(l + len, bb)
      ..lineTo(l + r, bb)
      ..arcTo(Rect.fromLTWH(l, bb - r * 2, r * 2, r * 2), math.pi / 2,
          math.pi / 2, false)
      ..lineTo(l, bb - len);

    // Glow under the brackets
    canvas.drawPath(
      path,
      Paint()
        ..color = _C.glow.withAlpha((90 + pulse * 130).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Sharp brackets
    canvas.drawPath(
      path,
      Paint()
        ..color = _C.glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Lens crosshair in the centre (dashed ring + small plus)
    final c = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = const Color(0x66CFC3CC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashes = 24;
    for (var i = 0; i < dashes; i++) {
      final start = i * (math.pi * 2 / dashes);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 32),
        start,
        math.pi * 2 / dashes * 0.55,
        false,
        ring,
      );
    }
    final plus = Paint()
      ..color = const Color(0xCCFE8357)
      ..strokeWidth = 1;
    canvas.drawLine(c.translate(-8, 0), c.translate(8, 0), plus);
    canvas.drawLine(c.translate(0, -8), c.translate(0, 8), plus);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter old) => old.pulse != pulse;
}