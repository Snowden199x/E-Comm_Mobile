import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/auth/screens/login_screen.dart';

class RiderWorkScreen extends StatefulWidget {
  const RiderWorkScreen({super.key});

  @override
  State<RiderWorkScreen> createState() => _RiderWorkScreenState();
}

class _RiderWorkScreenState extends State<RiderWorkScreen> {
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _name;
  String? _center;
  String? _vehicleType;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final work = await RiderApi.instance.assignments();
      final name = await RiderApi.instance.riderName();
      final center = await RiderApi.instance.centerName();
      final vehicleType = await RiderApi.instance.riderVehicleType();
      if (mounted) setState(() {
        _assignments = work;
        _name = name;
        _center = center;
        _vehicleType = vehicleType;
      });
    } on RiderApiException catch (error) {
      if (mounted && (error.statusCode == 401 || error.statusCode == 403)) {
        await RiderApi.instance.clearSession();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot reach Vendo. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _scanType(Map<String, dynamic> order) {
    final status = order['status'];
    if (order['assignment'] == 'pickup') {
      if (status == 'ready_for_pickup') return 'pickup';
      if (status == 'picked_up') return 'origin_arrival';
    }
    if (order['assignment'] == 'delivery') {
      if (status == 'assigned_to_rider') return 'out_for_delivery';
      if (status == 'out_for_delivery') return 'delivered';
    }
    return null;
  }

  String _scanLabel(String type) => switch (type) {
    'pickup' => 'Scan seller pickup',
    'origin_arrival' => 'Scan at origin hub',
    'delivered' => 'Scan after handing over parcel',
    _ => 'Scan out for delivery',
  };

  bool _supportsAssignment(Map<String, dynamic> order) {
    final assignment = order['assignment'];
    if (_vehicleType == 'Truck') return assignment != 'delivery';
    return assignment != 'linehaul';
  }

  Future<void> _scan(Map<String, dynamic> order, String type) async {
    if (_busy) return;
    final tracking = order['tracking_number'] as String;
    final scanned = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (_) => _ParcelScanner(trackingNumber: tracking)));
    if (!mounted || scanned == null) return;

    Map<String, dynamic>? deliveryProof;
    if (type == 'delivered' && order['delivery_proof_required'] == true) {
      deliveryProof = await _collectDeliveryProof();
      if (!mounted || deliveryProof == null) return;
    }

    setState(() => _busy = true);
    final api = RiderApi.instance;
    try {
      var key = await api.pendingScanKey(tracking, type);
      if (key == null) {
        key = _newUuid();
        await api.saveScanKey(tracking, type, key);
      }
      final result = deliveryProof == null
          ? await api.scan(tracking, type, key)
          : await api.submitDeliveryProof(
              trackingNumber: tracking,
              scanKey: key,
              recipientName: deliveryProof['recipient'] as String,
              photoPath: deliveryProof['photo'] as String,
            );
      await api.clearScanKey(tracking, type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['duplicate'] == true
            ? 'Scan already recorded. Parcel status is up to date.'
            : 'Scan saved. Seller and buyer tracking is updated.'),
      ));
      await _refresh();
    } on RiderApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connection failed. Scan this parcel again to retry the same event.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportTaskIssue(Map<String, dynamic> task) async {
    final detailsController = TextEditingController();
    var reason = 'other';
    final issue = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report a task issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: const [
                  DropdownMenuItem(value: 'damaged', child: Text('Parcel damaged')),
                  DropdownMenuItem(value: 'recipient_unavailable', child: Text('Recipient unavailable')),
                  DropdownMenuItem(value: 'unsafe_location', child: Text('Unsafe location')),
                  DropdownMenuItem(value: 'vehicle_issue', child: Text('Vehicle issue')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => reason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: detailsController.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'reason': reason,
                      'details': detailsController.text.trim(),
                    }),
              child: const Text('Send to Logistics'),
            ),
          ],
        ),
      ),
    );
    if (issue == null || !mounted) {
      detailsController.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await RiderApi.instance.reportTaskException(
        taskId: task['id'] as int,
        reason: issue['reason']!,
        details: issue['details']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Issue sent to Logistics.')),
        );
      }
      await _refresh();
    } on RiderApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the issue. Check your connection and retry.')),
      );
    } finally {
      detailsController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _collectDeliveryProof() async {
    final nameController = TextEditingController();
    XFile? photo;
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Confirm delivery'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter the recipient name and take a delivery photo.'),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Recipient name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final captured = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                      maxWidth: 1600,
                      maxHeight: 1600,
                    );
                    if (captured == null || !context.mounted) return;
                    final bytes = await captured.length();
                    if (bytes > 5 * 1024 * 1024) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Photo must be 5 MB or smaller.')),
                      );
                      return;
                    }
                    setDialogState(() => photo = captured);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(photo == null ? 'Take photo' : 'Retake photo'),
                ),
                if (photo != null)
                  Text(photo!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: photo == null || nameController.text.trim().length < 2
                    ? null
                    : () => Navigator.pop(dialogContext, {
                        'recipient': nameController.text.trim(),
                        'photo': photo!.path,
                      }),
                child: const Text('Submit proof'),
              ),
            ],
          ),
        ),
      );
    } on RiderApiException {
      rethrow;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the camera. Check camera permission and retry.')),
        );
      }
      return null;
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _scanFacility(
    Map<String, dynamic> order,
    Map<String, dynamic> target,
  ) async {
    if (_busy) return;
    final tracking = order['tracking_number'] as String;
    final facilityId = (target['facility_id'] as num).toInt();
    final scanned = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (_) => _ParcelScanner(trackingNumber: tracking)));
    if (!mounted || scanned == null) return;

    final scanType = 'facility-$facilityId';
    setState(() => _busy = true);
    final api = RiderApi.instance;
    try {
      var key = await api.pendingScanKey(tracking, scanType);
      if (key == null) {
        key = _newUuid();
        await api.saveScanKey(tracking, scanType, key);
      }
      final result = await api.scanFacility(tracking, facilityId, key);
      await api.clearScanKey(tracking, scanType);
      if (!mounted) return;
      final facilityName = result['facility']?.toString() ?? 'facility';
      final action = result['action']?.toString() ?? 'scan';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['duplicate'] == true
            ? 'This scan was already recorded. Parcel status is up to date.'
            : 'Scan saved at $facilityName ($action). Seller and buyer tracking is updated.'),
      ));
      await _refresh();
    } on RiderApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connection failed. Scan this parcel again to retry the same event.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await RiderApi.instance.logout();
      if (mounted) Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not sign out from the server. Check your connection.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF2D1B3D);
    final visibleAssignments = _assignments.where(_supportsAssignment).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FB),
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        title: const Text('Assigned parcels'),
        actions: [
          IconButton(tooltip: 'Refresh assignments', onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Sign out', onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12), TextButton(onPressed: _refresh, child: const Text('Retry'))],
                )))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_name == null ? 'Rider work' : 'Hello, $_name',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: purple)),
                      if (_vehicleType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _vehicleType == 'Truck' ? 'Truck Rider · Long-haul' : '$_vehicleType Rider · Local pickup and delivery',
                            style: const TextStyle(color: Color(0xFF66606D)),
                          ),
                        ),
                      if (_center != null) Text('Logistics hub: $_center',
                        style: const TextStyle(color: Color(0xFF66606D))),
                      const SizedBox(height: 16),
                      if (visibleAssignments.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(24),
                          child: Text(_vehicleType == 'Truck'
                              ? 'No truck linehaul assignments yet. The Main Hub assigns a Truck Rider after sorting the parcel.'
                              : 'No pickup or delivery assignments yet. Pull down to refresh.'))),
                      ...visibleAssignments.map((order) {
                        final type = _scanType(order);
                        final task = order['task'] is Map
                            ? Map<String, dynamic>.from(order['task'] as Map)
                            : null;
                        final taskFailed = task?['status'] == 'failed';
                        final stop = Map<String, dynamic>.from(order['stop'] as Map);
                        final plannedRoute = order['planned_route'] is Map
                            ? Map<String, dynamic>.from(order['planned_route'] as Map)
                            : null;
                        final checkpoints = plannedRoute?['checkpoints'] is List
                            ? plannedRoute!['checkpoints'] as List<dynamic>
                            : const <dynamic>[];
                        final scanTarget = plannedRoute?['scan_target'] is Map
                            ? Map<String, dynamic>.from(plannedRoute!['scan_target'] as Map)
                            : null;
                        final nextCheckpoint = plannedRoute?['next_checkpoint'] is Map
                            ? Map<String, dynamic>.from(plannedRoute!['next_checkpoint'] as Map)
                            : null;
                        final routeNames = <String>[
                          plannedRoute?['origin_main_hub']?.toString() ?? '',
                          ...checkpoints.map((checkpoint) {
                            if (checkpoint is! Map) return '';
                            final data = Map<String, dynamic>.from(checkpoint);
                            final code = data['code']?.toString();
                            final name = data['name']?.toString();
                            return [code, name].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
                          }),
                          plannedRoute?['destination_main_hub']?.toString() ?? '',
                        ].where((value) => value.isNotEmpty).toList();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(order['tracking_number']?.toString() ?? '',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('${order['assignment'] == 'pickup' ? 'Pickup' : order['assignment'] == 'linehaul' ? 'Truck linehaul' : 'Delivery'} · ${order['status']}',
                                style: const TextStyle(color: Color(0xFF6D6475))),
                              const Divider(height: 24),
                              Text(stop['name']?.toString() ?? 'Stop',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(stop['address']?.toString() ?? 'Address unavailable'),
                              if (stop['phone'] != null) Text(stop['phone'].toString()),
                              const SizedBox(height: 8),
                              Text('Origin: ${order['pickup_center'] ?? 'Unassigned'}'),
                              Text('Destination: ${order['destination_center'] ?? 'Unassigned'}'),
                              if (plannedRoute != null) ...[
                                const Divider(height: 24),
                                const Text('Planned truck route', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(routeNames.join(' → ')),
                                if (nextCheckpoint != null)
                                  Text('Next planned checkpoint: ' + [
                                    nextCheckpoint['code']?.toString(),
                                    nextCheckpoint['name']?.toString(),
                                  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ')),
                                if (scanTarget != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Scan target: ' + scanTarget['name'].toString() +
                                          (scanTarget['municipality'] == null
                                              ? ''
                                              : ' · ' + scanTarget['municipality'].toString()),
                                      style: const TextStyle(color: Color(0xFF6D6475)),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 12),
                              if (order['assignment'] == 'linehaul' && scanTarget != null)
                                SizedBox(width: double.infinity, child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: purple),
                                  onPressed: _busy ? null : () => _scanFacility(order, scanTarget),
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: Text('Scan at ' + scanTarget['name'].toString()),
                                ))
                              else if (order['assignment'] == 'linehaul')
                                const Text('No facility scan is due yet. Refresh after Logistics sets the route or the previous stop is completed.',
                                  style: TextStyle(color: Color(0xFF6D6475)))
                              else if (type != null && !taskFailed)
                                SizedBox(width: double.infinity, child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: purple),
                                  onPressed: _busy ? null : () => _scan(order, type),
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: Text(
                                    type == 'delivered' && order['delivery_proof_required'] == true
                                        ? 'Scan and add delivery proof'
                                        : _scanLabel(type),
                                  ),
                                ))
                              else const Text('No rider scan is available at this stage.',
                                style: TextStyle(color: Color(0xFF6D6475))),
                              if (taskFailed) ...[
                                const SizedBox(height: 8),
                                Text('Paused: ${task?['failure_reason'] ?? 'Logistics needs to review this task.'}',
                                    style: const TextStyle(color: Color(0xFF9A3E35))),
                              ],
                              if (task != null && !taskFailed
                                  && ['assigned', 'in_progress'].contains(task['status'])) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: _busy ? null : () => _reportTaskIssue(task),
                                  icon: const Icon(Icons.report_problem_outlined),
                                  label: const Text('Report an issue'),
                                ),
                              ],
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _ParcelScanner extends StatefulWidget {
  const _ParcelScanner({required this.trackingNumber});
  final String trackingNumber;

  @override
  State<_ParcelScanner> createState() => _ParcelScannerState();
}

class _ParcelScannerState extends State<_ParcelScanner> {
  final MobileScannerController? _mobileCamera = defaultTargetPlatform == TargetPlatform.linux
      ? null
      : MobileScannerController(
          formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
        );
  bool _found = false;
  Process? _linuxCamera;
  StreamSubscription<String>? _linuxCodes;
  String _cameraMessage = 'Opening laptop camera…';

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.linux) _startLinuxCamera();
  }

  Future<void> _startLinuxCamera() async {
    try {
      final camera = await Process.start('zbarcam', [
        '--raw',
        '--set', 'qrcode.enable=1',
        '--set', 'code128.enable=1',
      ]);
      if (!mounted) {
        camera.kill();
        return;
      }
      _linuxCamera = camera;
      setState(() => _cameraMessage = 'Point the laptop camera at the printed QR or barcode. The camera preview opens in a separate window.');
      _linuxCodes = camera.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((code) {
        if (_found || !mounted) return;
        if (code.trim() == widget.trackingNumber) {
          _found = true;
          Navigator.pop(context, widget.trackingNumber);
        } else if (code.trim().isNotEmpty) {
          setState(() => _cameraMessage = 'That code belongs to a different parcel. Scan the assigned label.');
        }
      });
      final exitCode = await camera.exitCode;
      if (mounted && !_found) {
        setState(() => _cameraMessage = 'Camera reader closed (exit $exitCode). Check webcam access and retry.');
      }
    } on ProcessException {
      if (mounted) setState(() => _cameraMessage = 'Linux camera reader is missing. Install Fedora package zbar, then reopen this scan.');
    }
  }

  @override
  void dispose() {
    _linuxCodes?.cancel();
    _linuxCamera?.kill();
    if (_mobileCamera != null) unawaited(_mobileCamera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan shipping label')),
    body: Column(children: [
      Expanded(child: defaultTargetPlatform == TargetPlatform.linux
        ? Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_cameraMessage, textAlign: TextAlign.center),
          ))
        : MobileScanner(
        controller: _mobileCamera!,
        onDetect: (capture) {
          if (_found) return;
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue == widget.trackingNumber) {
              _found = true;
              Navigator.pop(context, widget.trackingNumber);
              return;
            }
          }
        },
      )),
      Padding(padding: const EdgeInsets.all(20), child: Text(
        'Scan the barcode or QR on ${widget.trackingNumber}. Only this assigned parcel will be accepted.',
        textAlign: TextAlign.center,
      )),
    ]),
  );
}
