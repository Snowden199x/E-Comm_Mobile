import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Stand-alone scanner opened from the Home "Assign Parcel to Me" button.
///
/// Scans any QR or Code-128 barcode and pops with the raw value.
/// The caller decides what to do with it (navigate to Deliveries, etc.).
class ParcelScannerScreen extends StatefulWidget {
  const ParcelScannerScreen({super.key});

  @override
  State<ParcelScannerScreen> createState() => _ParcelScannerScreenState();
}

class _ParcelScannerScreenState extends State<ParcelScannerScreen> {
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

  @override
  void initState() {
    super.initState();
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
            if (code.trim().isNotEmpty) {
              _found = true;
              Navigator.pop(context, code.trim());
            }
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

  @override
  void dispose() {
    _linuxSub?.cancel();
    _linuxProc?.kill();
    if (_camera != null) unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1B3D),
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Parcel',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_camera != null)
            IconButton(
              tooltip: 'Toggle flashlight',
              icon: const Icon(Icons.flashlight_on_outlined),
              onPressed: () => _camera.toggleTorch(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Camera viewfinder ────────────────────────────────
          Expanded(
            child: defaultTargetPlatform == TargetPlatform.linux
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _camera!,
                        onDetect: (capture) {
                          if (_found) return;
                          for (final barcode in capture.barcodes) {
                            final raw = barcode.rawValue;
                            if (raw != null && raw.isNotEmpty) {
                              _found = true;
                              Navigator.pop(context, raw);
                              return;
                            }
                          }
                        },
                      ),
                      // Scanning overlay — corner brackets
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _ScanOverlayPainter(),
                      ),
                    ],
                  ),
          ),

          // ── Instruction bar ──────────────────────────────────
          Container(
            width: double.infinity,
            color: const Color(0xFF1A0D2E),
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  'Align the QR code or barcode inside the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Scanning will happen automatically',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Corner bracket overlay
// ─────────────────────────────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(0, len), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - len), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
