import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';
import 'package:vendo_driver/features/trips/screens/driver_dispatch_screen.dart';

/// The first step of a scheduled trip: every parcel is scanned onto the truck.
///
/// One label can name a single parcel or a whole container, so a scan may load
/// several parcels at once. Dispatch is not offered here until the last parcel
/// is scanned, and each scan is saved to Vendo as the origin departure scan the
/// server checks before it lets the trip leave. A driver without a working
/// camera can type the tracking number instead, so a dead camera never strands
/// a load.
class DriverScanScreen extends StatefulWidget {
  const DriverScanScreen({super.key, required this.tripCode});

  final String tripCode;

  @override
  State<DriverScanScreen> createState() => _DriverScanScreenState();
}

class _DriverScanScreenState extends State<DriverScanScreen> {
  final TextEditingController _manual = TextEditingController();
  MobileScannerController? _camera;
  bool _busy = false;
  bool _starting = false;
  String? _cameraFailure;
  bool _feedbackOk = true;
  String? _feedback;
  String _lastCode = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // The Linux desktop build has no Flutter camera reader, so it starts on the
    // typed tracking number instead of a preview that can never open.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.linux) {
      // The camera is started by the screen, not by the widget, so a slow or
      // wedged start can be given a deadline and reported instead of spinning
      // forever on "Starting the camera…".
      _camera = MobileScannerController(
        autoStart: false,
        formats: const [
          BarcodeFormat.qrCode,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.ean13,
        ],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    final camera = _camera;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final store = DriverStore.instance;
    final trip = store.tripByCode(widget.tripCode);
    final payload = raw.trim();
    if (trip == null || _busy || payload.isEmpty) return;

    // A camera keeps reporting the same barcode while it is in frame, so the
    // same label is ignored for a moment after it is scanned.
    final now = DateTime.now();
    if (payload == _lastCode &&
        now.difference(_lastAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastCode = payload;
    _lastAt = now;

    final codes = _codesFromPayload(payload, trip);
    if (codes.isEmpty) {
      setState(() {
        _feedbackOk = false;
        _feedback =
            'That label does not carry a tracking number. Check the label and '
            'scan it again.';
      });
      _manual.clear();
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });
    final result = await store.scanLoadParcels(trip, codes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedbackOk = result.ok;
      _feedback = result.message;
    });
    _manual.clear();
  }

  /// Turns one scanned label into the tracking numbers it carries.
  ///
  /// A parcel label holds one number. A container label holds several, listed
  /// with commas, semicolons, pipes, spaces or line breaks, optionally behind a
  /// scheme prefix (`VENDO-CONTAINER:`) or as a JSON list. The trip's own QR
  /// code stands for the whole manifest.
  List<String> _codesFromPayload(String raw, DriverTrip trip) {
    final payload = raw.trim();
    if (payload.isEmpty) return const [];

    if (payload.toUpperCase() == trip.code.toUpperCase()) {
      return trip.trackingNumbers.toList(growable: false);
    }

    final withoutPrefix = payload.replaceFirst(
      RegExp(
        r'^(vendo[-_][a-z0-9_-]*|container|bulk)\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );

    final tokens = <String>[];
    void addTokens(Object? value) {
      if (value is String) {
        tokens.addAll(value.split(RegExp(r'[\s,;|]+')));
      } else if (value is List) {
        for (final entry in value) {
          addTokens(entry);
        }
      }
    }

    if (withoutPrefix.startsWith('[') || withoutPrefix.startsWith('{')) {
      try {
        final decoded = jsonDecode(withoutPrefix);
        if (decoded is Map) {
          addTokens(decoded['tracking_numbers']);
          addTokens(decoded['tracking_number']);
        } else {
          addTokens(decoded);
        }
      } on FormatException {
        // Not JSON after all; the plain list below handles the text.
      }
    }
    if (tokens.isEmpty) addTokens(withoutPrefix);

    final codes = <String>[];
    for (final token in tokens) {
      final code = token.trim();
      if (code.length < 5 || code.length > 100) continue;
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]*$').hasMatch(code)) continue;
      if (!codes.contains(code)) codes.add(code);
    }
    return codes;
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isNotEmpty) {
        unawaited(_submit(raw));
        return;
      }
    }
  }

  /// Starts the camera and gives up after eight seconds.
  ///
  /// mobile_scanner can sit on a wedged CameraX start — another app holding the
  /// camera, a device that never answers the permission prompt — and an endless
  /// "Starting…" box tells the driver nothing. A slow start becomes a stated
  /// problem with a retry, and the typed tracking numbers keep working.
  Future<void> _startCamera() async {
    final camera = _camera;
    if (camera == null || _starting) return;
    setState(() {
      _starting = true;
      _cameraFailure = null;
    });
    try {
      await camera.start().timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _starting = false);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _cameraFailure =
            'The camera is taking too long to start. Close any other app that '
            'is using the camera, then tap Try again — or type the tracking '
            'numbers below.';
      });
      try {
        await camera.stop();
      } catch (_) {
        // Best effort: the retry starts from a clean controller either way.
      }
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _cameraFailure = _cameraMessage(error);
      });
    }
  }

  Future<void> _retryCamera() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.stop();
    } catch (_) {
      // Stopping a camera that never started throws; the start below is what
      // matters.
    }
    await _startCamera();
  }

  String _cameraMessage(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission is denied. Allow the camera for Vendo Driver in the '
            'phone settings, then tap Try again.',
      MobileScannerErrorCode.unsupported =>
        'This device cannot run the camera reader. Type the tracking numbers '
            'below instead.',
      _ =>
        'The camera did not start. Close any other app that is using it, then '
            'tap Try again.',
    };
  }

  Widget _cameraProblem(String message, {bool denied = false}) {
    return ColoredBox(
      color: VColors.prune,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _retryCamera,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x88FFFFFF)),
                  minimumSize: const Size(0, 34),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDispatch(DriverTrip trip) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DriverDispatchScreen(tripCode: trip.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.tripByCode(widget.tripCode);
        if (trip == null) {
          return Scaffold(
            backgroundColor: VColors.background,
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                DriverHeader(
                  eyebrow: 'Load scan',
                  title: 'Trip not found',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: vPageInsets,
                  child: const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'This trip is no longer on the device',
                    message: 'Open the trip board again to refresh your work.',
                  ),
                ),
              ],
            ),
          );
        }

        final total = trip.parcelCount;
        final scanned = trip.originScanned > total
            ? total
            : trip.originScanned;
        final ready = trip.readyToDepart;
        final remaining = total - scanned;

        return Scaffold(
          backgroundColor: VColors.background,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              DriverHeader(
                eyebrow: 'Load scan',
                title: 'Scan parcels',
                subtitle:
                    '${trip.code}  ·  ${trip.origin}  →  ${trip.destination}',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: TripStatusPill(status: trip.status),
              ),
              Padding(
                padding: vPageInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScanCounter(
                      scanned: scanned,
                      total: total,
                      hub: trip.origin,
                    ),
                    const SizedBox(height: 16),
                    _scannerCard(),
                    const SizedBox(height: 10),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.view_agenda_outlined,
                          color: VColors.muted,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A parcel label holds one tracking number. A '
                            'container label that lists several loads every '
                            'parcel on it in one scan.',
                            style: TextStyle(
                              color: VColors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manual,
                      enabled: !_busy,
                      cursorColor: VColors.prune,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: 'Scan or type a tracking number',
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                        ),
                        suffixIcon: TextButton(
                          onPressed: _busy ? null : () => _submit(_manual.text),
                          child: const Text('Scan'),
                        ),
                      ),
                    ),
                    if (_feedback != null) ...[
                      const SizedBox(height: 12),
                      _feedbackBanner(_feedback!),
                    ],
                    const SizedBox(height: 20),
                    SectionTitle(
                      'Parcels on this trip',
                      trailing: Text(
                        '$scanned of $total',
                        style: const TextStyle(
                          color: VColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    VCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < trip.trackingNumbers.length;
                            i++
                          ) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                            _ParcelScanRow(
                              tracking: trip.trackingNumbers[i],
                              scanned: trip.originScanRecorded(
                                trip.trackingNumbers[i],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    NoticeCard(
                      icon: ready
                          ? Icons.verified_outlined
                          : Icons.qr_code_scanner_rounded,
                      tone: ready ? NoticeTone.success : NoticeTone.warning,
                      title: ready
                          ? 'Every parcel is on board'
                          : 'Dispatch unlocks after the last scan',
                      message: ready
                          ? 'Confirm dispatch now moves $total '
                                '${total == 1 ? 'parcel' : 'parcels'} to In '
                                'Transit. ${trip.destination} scans them again '
                                'on arrival.'
                          : '$remaining '
                                '${remaining == 1 ? 'parcel is' : 'parcels are'} '
                                'still unscanned. Confirm dispatch stays locked '
                                'until every parcel is scanned onto the truck.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: DriverBottomAction(
            child: FilledButton(
              onPressed: ready && !_busy ? () => _openDispatch(trip) : null,
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
                      ready
                          ? 'Confirm dispatch'
                          : 'Scan every parcel to dispatch',
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _scannerCard() {
    final camera = _camera;

    return VCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          child: camera == null
              ? Container(
                  color: VColors.raisin,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: const Text(
                    'The camera reader is not available on this device. Type '
                    'the tracking number below to scan the parcel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cameraFailure != null)
                      _cameraProblem(_cameraFailure!)
                    else
                      MobileScanner(
                        controller: camera,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => _cameraProblem(
                          _cameraMessage(error),
                          denied:
                              error.errorCode ==
                              MobileScannerErrorCode.permissionDenied,
                        ),
                        placeholderBuilder: (context) => const ColoredBox(
                          color: VColors.prune,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: VColors.lin),
                                SizedBox(height: 12),
                                Text(
                                  'Starting the camera…',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_cameraFailure == null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          tooltip: 'Torch',
                          onPressed: () => unawaited(camera.toggleTorch()),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x66000000),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(
                            Icons.flashlight_on_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    if (_busy)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _feedbackBanner(String message) {
    final ok = _feedbackOk;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? VColors.greenSoft : VColors.redSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            color: ok ? VColors.green : VColors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ok ? VColors.green : VColors.red,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCounter extends StatelessWidget {
  const _ScanCounter({
    required this.scanned,
    required this.total,
    required this.hub,
  });

  final int scanned;
  final int total;
  final String hub;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (scanned / total).clamp(0.0, 1.0);
    final done = total > 0 && scanned >= total;

    return VCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done ? VColors.greenSoft : VColors.raisinSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.verified_rounded : Icons.qr_code_scanner_rounded,
                  color: done ? VColors.green : VColors.raisin,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$scanned of $total scanned',
                      style: const TextStyle(
                        color: VColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? 'The load matches the manifest'
                          : 'Scan each parcel at $hub',
                      style: const TextStyle(
                        color: VColors.muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              color: done ? VColors.green : VColors.raisin,
              backgroundColor: VColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelScanRow extends StatelessWidget {
  const _ParcelScanRow({required this.tracking, required this.scanned});

  final String tracking;
  final bool scanned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scanned ? VColors.greenSoft : VColors.raisinSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              scanned ? Icons.check_rounded : Icons.inventory_2_outlined,
              color: scanned ? VColors.green : VColors.raisin,
              size: 16,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scanned ? 'Scanned onto the truck' : 'Waiting for a scan',
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            scanned ? 'On board' : 'Pending',
            style: TextStyle(
              color: scanned ? VColors.green : const Color(0xFF8A6D1A),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
