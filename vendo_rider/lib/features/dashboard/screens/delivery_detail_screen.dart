import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the rest of the dashboard
//  • Prune   → dark header, main button, main text
//  • Brique  → accent (status, drop-off, section bars)
//  • Lin     → soft gold for key details on dark
//  • Raisin  → icons and secondary tones
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
  static const briqueSoft = Color(0xFFF8EAE5);
  static const goldSoft = Color(0xFFF8F1DC);
  static const disabled = Color(0xFFD9D2DA);
  static const shadow = Color(0x1A412143);
}

const double _radius = 16;

// ─────────────────────────────────────────────────────────────────────────────
// Assignment helpers (shared with deliveries_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

/// Rider-facing stage of an assigned parcel. Derived only from the server
/// status the assignment API returned; the app never guesses a stage.
enum RiderStage {
  readyForPickup,
  onTheWayToHub,
  forDelivery,
  onTheWayToBuyer,
  linehaul,
  other,
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

String _text(dynamic value) => value?.toString().trim() ?? '';

RiderStage riderStageOf(Map<String, dynamic> order) {
  if (order['assignment'] == 'linehaul') return RiderStage.linehaul;
  switch (order['status']?.toString()) {
    case 'ready_for_pickup':
      return RiderStage.readyForPickup;
    case 'picked_up':
      return RiderStage.onTheWayToHub;
    case 'assigned_to_rider':
      return RiderStage.forDelivery;
    case 'out_for_delivery':
      return RiderStage.onTheWayToBuyer;
    default:
      return RiderStage.other;
  }
}

String riderAssignmentLabel(Map<String, dynamic> order) {
  switch (order['assignment']) {
    case 'pickup':
      return 'Pickup';
    case 'linehaul':
      return 'Truck linehaul';
    default:
      return 'Delivery';
  }
}

/// Short chip text for the stage.
String riderStageBadge(RiderStage stage) => switch (stage) {
  RiderStage.readyForPickup => 'For pickup',
  RiderStage.onTheWayToHub => 'On the way',
  RiderStage.forDelivery => 'For delivery',
  RiderStage.onTheWayToBuyer => 'On the way',
  RiderStage.linehaul => 'Linehaul',
  RiderStage.other => 'Assigned',
};

/// The next server-provided stop on a Truck linehaul route, when set.
Map<String, dynamic> riderRouteTarget(Map<String, dynamic> order) {
  final route = _map(order['planned_route']);
  final target = _map(route['scan_target']);
  if (target.isNotEmpty && _text(target['name']).isNotEmpty) return target;
  return _map(route['next_checkpoint']);
}

/// Headline for the parcel card and the detail banner.
String riderStageTitle(Map<String, dynamic> order) {
  final stopName = _text(_map(order['stop'])['name']);
  final hub = _text(order['pickup_center']);
  switch (riderStageOf(order)) {
    case RiderStage.readyForPickup:
      return stopName.isEmpty
          ? 'Pick up from the seller'
          : 'Pick up from $stopName';
    case RiderStage.onTheWayToHub:
      return hub.isEmpty
          ? 'On the way to the origin hub'
          : 'On the way to $hub';
    case RiderStage.forDelivery:
      return stopName.isEmpty ? 'Ready for delivery' : 'Deliver to $stopName';
    case RiderStage.onTheWayToBuyer:
      return stopName.isEmpty
          ? 'On the way to the buyer'
          : 'On the way to $stopName';
    case RiderStage.linehaul:
      final target = _text(riderRouteTarget(order)['name']);
      return target.isEmpty ? 'Truck linehaul' : 'Next stop: $target';
    case RiderStage.other:
      return 'Assigned parcel';
  }
}

/// Supporting line under the headline: address, hub instruction, or route note.
String riderStageSubtitle(Map<String, dynamic> order) {
  final stop = _map(order['stop']);
  final address = _text(stop['address']);
  final hub = _text(order['pickup_center']);
  switch (riderStageOf(order)) {
    case RiderStage.readyForPickup:
    case RiderStage.forDelivery:
    case RiderStage.onTheWayToBuyer:
      return address.isEmpty ? 'Address unavailable' : address;
    case RiderStage.onTheWayToHub:
      return hub.isEmpty
          ? 'Bring the parcel to the origin hub for sorting.'
          : 'Bring the parcel to $hub for sorting.';
    case RiderStage.linehaul:
      final route = _map(order['planned_route']);
      final scanTarget = _map(route['scan_target']);
      final nextCheckpoint = _map(route['next_checkpoint']);
      final label = [
        _text(scanTarget['name']),
        _text(scanTarget['municipality']),
      ].where((value) => value.isNotEmpty).join(' · ');
      if (label.isNotEmpty) return 'Scan at $label when you arrive.';
      final planned = [
        _text(nextCheckpoint['name']),
        _text(nextCheckpoint['municipality']),
      ].where((value) => value.isNotEmpty).join(' · ');
      return planned.isEmpty
          ? 'Waiting for the next route stop from Logistics.'
          : 'Next planned checkpoint: $planned.';
    case RiderStage.other:
      return _text(order['status']).replaceAll('_', ' ');
  }
}

/// Server-supported scan action for the current status, or null when no scan
/// is due.
String? riderScanTypeFor(Map<String, dynamic> order) {
  final status = order['status']?.toString();
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

String riderScanLabelFor(String type) => switch (type) {
  'pickup' => 'Scan seller pickup',
  'origin_arrival' => 'Scan at origin hub',
  'delivered' => 'Scan after handing over parcel',
  _ => 'Scan out for delivery',
};

bool riderSupportsAssignment(Map<String, dynamic> order, String? vehicleType) {
  final assignment = order['assignment'];
  if (vehicleType == 'Truck') return assignment != 'delivery';
  return assignment != 'linehaul';
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail screen
// ─────────────────────────────────────────────────────────────────────────────
class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.order});

  /// One assignment row exactly as `GET /api/v1/rider/assignments` returned it.
  final Map<String, dynamic> order;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  late Map<String, dynamic> _order;
  bool _busy = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  // ── Server state ─────────────────────────────────────────────────
  /// Re-reads this parcel from the assignment API so the screen never shows a
  /// stage the server has not confirmed. When the parcel leaves the Rider's
  /// active work the screen shows a finished state instead of a stale action.
  Future<void> _refreshOrder() async {
    try {
      final work = await RiderApi.instance.assignments();
      Map<String, dynamic>? match;
      for (final item in work) {
        if (item['order_id'] == _order['order_id']) {
          match = item;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        if (match != null) {
          _order = match;
        } else {
          _finished = true;
        }
      });
    } catch (_) {
      // Keep the last server-confirmed state; the scan result was already shown.
    }
  }

  // ── Scanning ─────────────────────────────────────────────────────
  Future<void> _scan() async {
    final type = riderScanTypeFor(_order);
    if (type == null || _busy) return;
    final tracking = _text(_order['tracking_number']);
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _ParcelScanner(trackingNumber: tracking),
      ),
    );
    if (!mounted || scanned == null) return;

    Map<String, String>? deliveryProof;
    if (type == 'delivered' && _order['delivery_proof_required'] == true) {
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
              recipientName: deliveryProof['recipient']!,
              photoPath: deliveryProof['photo']!,
            );
      await api.clearScanKey(tracking, type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['duplicate'] == true
                ? 'Scan already recorded. Parcel status is up to date.'
                : 'Scan saved. Seller and buyer tracking is updated.',
          ),
        ),
      );
      await _refreshOrder();
    } on RiderApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) await _refreshOrder();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection failed. Scan this parcel again to retry the same event.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanFacility() async {
    if (_busy) return;
    final target = _map(_map(_order['planned_route'])['scan_target']);
    final facilityId = target['facility_id'];
    if (facilityId is! num) return;
    final tracking = _text(_order['tracking_number']);
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _ParcelScanner(trackingNumber: tracking),
      ),
    );
    if (!mounted || scanned == null) return;

    final scanType = 'facility-${facilityId.toInt()}';
    setState(() => _busy = true);
    final api = RiderApi.instance;
    try {
      var key = await api.pendingScanKey(tracking, scanType);
      if (key == null) {
        key = _newUuid();
        await api.saveScanKey(tracking, scanType, key);
      }
      final result = await api.scanFacility(tracking, facilityId.toInt(), key);
      await api.clearScanKey(tracking, scanType);
      if (!mounted) return;
      final facilityName = result['facility']?.toString() ?? 'facility';
      final action = result['action']?.toString() ?? 'scan';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['duplicate'] == true
                ? 'This scan was already recorded. Parcel status is up to date.'
                : 'Scan saved at $facilityName ($action). Seller and buyer tracking is updated.',
          ),
        ),
      );
      await _refreshOrder();
    } on RiderApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.statusCode == 409) await _refreshOrder();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection failed. Scan this parcel again to retry the same event.',
            ),
          ),
        );
      }
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
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: const [
                  DropdownMenuItem(
                    value: 'damaged',
                    child: Text('Parcel damaged'),
                  ),
                  DropdownMenuItem(
                    value: 'recipient_unavailable',
                    child: Text('Recipient unavailable'),
                  ),
                  DropdownMenuItem(
                    value: 'unsafe_location',
                    child: Text('Unsafe location'),
                  ),
                  DropdownMenuItem(
                    value: 'vehicle_issue',
                    child: Text('Vehicle issue'),
                  ),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
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
        taskId: (task['id'] as num).toInt(),
        reason: issue['reason']!,
        details: issue['details']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Issue sent to Logistics.',
            ),
          ),
        );
      }
      await _refreshOrder();
    } on RiderApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      if (error.statusCode == 409) await _refreshOrder();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send the issue. Check your connection and retry.',
            ),
          ),
        );
      }
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
                const Text(
                  'Enter the recipient name and take a delivery photo.',
                ),
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
                    if (!mounted) return;
                    if (bytes > 5 * 1024 * 1024) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Photo must be 5 MB or smaller.'),
                        ),
                      );
                      return;
                    }
                    setDialogState(() => photo = captured);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(photo == null ? 'Take photo' : 'Retake photo'),
                ),
                if (photo != null)
                  Text(
                    photo!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    photo == null || nameController.text.trim().length < 2
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the camera. Check camera permission and retry.',
            ),
          ),
        );
      }
      return null;
    } finally {
      nameController.dispose();
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

  // ── Screen ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stage = riderStageOf(_order);
    final scanType = riderScanTypeFor(_order);
    final scanTarget = _map(_map(_order['planned_route'])['scan_target']);
    final task = _map(_order['task']);
    final taskFailed = task['status'] == 'failed';
    final canReportIssue =
        !_finished &&
        task.isNotEmpty &&
        !taskFailed &&
        ['assigned', 'in_progress'].contains(task['status']);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.background,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(stage),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_finished) ...[
                      _buildFinishedCard(),
                      const SizedBox(height: 20),
                    ] else if (stage == RiderStage.onTheWayToHub ||
                        stage == RiderStage.onTheWayToBuyer ||
                        (stage == RiderStage.linehaul &&
                            scanTarget['facility_id'] != null)) ...[
                      _buildOnTheWayBanner(stage),
                      const SizedBox(height: 20),
                    ],
                    _buildRouteSection(),
                    const SizedBox(height: 24),
                    _buildStopSection(),
                    const SizedBox(height: 24),
                    _buildActionSection(scanType, scanTarget, taskFailed),
                    if (canReportIssue) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _reportTaskIssue(task),
                          icon: const Icon(Icons.report_problem_outlined),
                          label: const Text('Report an issue'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(scanType, scanTarget, taskFailed),
      ),
    );
  }

  // ── Dark header: back button + tracking number + status ─────────
  Widget _buildHeader(RiderStage stage) {
    final topInset = MediaQuery.of(context).padding.top;
    final style = _stageStyle(stage);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.pruneLight, _C.prune],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x26FFFFFF)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Parcel Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        riderAssignmentLabel(_order).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _text(_order['tracking_number']).isEmpty
                            ? 'Assigned parcel'
                            : _text(_order['tracking_number']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.lin,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        riderStageTitle(_order),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: style.fg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riderStageBadge(stage),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── "On the way" banner: the next warehouse / station / buyer ───
  Widget _buildOnTheWayBanner(RiderStage stage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.briqueSoft,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _C.brique.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _C.brique,
              shape: BoxShape.circle,
            ),
            child: Icon(
              stage == RiderStage.onTheWayToBuyer
                  ? Icons.near_me_rounded
                  : Icons.local_shipping_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderStageTitle(_order),
                  style: const TextStyle(
                    color: _C.brique,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  riderStageSubtitle(_order),
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.raisinSoft,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _C.raisin.withAlpha(60)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: _C.raisin, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This parcel is no longer in your active work. Logistics has the next step.',
              style: TextStyle(color: _C.ink, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Route: where the parcel came from and where it goes next ────
  Widget _buildRouteSection() {
    final nodes = _routeNodes(_order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Route'),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                _RouteStop(node: nodes[i]),
                if (i < nodes.length - 1)
                  Container(
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.only(left: 9, top: 3, bottom: 3),
                    color: _C.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Stop / contact ───────────────────────────────────────────────
  Widget _buildStopSection() {
    final stop = _map(_order['stop']);
    final name = _text(stop['name']);
    final phone = _text(stop['phone']);
    final address = _text(stop['address']);
    final isSeller = _order['assignment'] == 'pickup';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(isSeller ? 'Seller' : 'Recipient'),
        const SizedBox(height: 12),
        _Card(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _C.raisinSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSeller ? Icons.storefront_outlined : Icons.person_rounded,
                  color: _C.raisin,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Contact unavailable' : name,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: const TextStyle(color: _C.muted, fontSize: 13),
                      ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        style: const TextStyle(
                          color: _C.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Scan action detail (the primary button is in the bottom bar) ─
  Widget _buildActionSection(
    String? scanType,
    Map<String, dynamic> scanTarget,
    bool taskFailed,
  ) {
    if (_finished) return const SizedBox.shrink();
    final hub = _text(_order['pickup_center']);
    String message;
    if (taskFailed) {
      message =
          'Paused: Logistics needs to review this task before you can scan.';
    } else if (scanTarget['facility_id'] is num) {
      message =
          'Scan the parcel label at ${_text(scanTarget['name'])}. The server checks the route order before accepting it.';
    } else if (scanType != null) {
      message = switch (scanType) {
        'pickup' =>
          'Scan the label when the seller hands you the parcel. The next step is $hub.',
        'origin_arrival' =>
          'You are carrying this parcel. Scan it at ${hub.isEmpty ? 'the origin hub' : hub} on arrival.',
        'out_for_delivery' =>
          'Scan the label when you leave for this delivery.',
        _ => 'Scan the label after handing the parcel to the recipient.',
      };
    } else if (_order['assignment'] == 'linehaul') {
      message =
          'No facility scan is due yet. Refresh after Logistics sets the route or the previous stop is completed.';
    } else {
      message = 'No rider scan is available at this stage.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Next action'),
        const SizedBox(height: 12),
        _Card(
          borderColor: taskFailed ? _C.brique : _C.border,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                taskFailed
                    ? Icons.error_outline_rounded
                    : Icons.qr_code_scanner_rounded,
                color: taskFailed ? _C.brique : _C.raisin,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom bar: the one action the server currently allows ──────
  Widget? _buildBottomBar(
    String? scanType,
    Map<String, dynamic> scanTarget,
    bool taskFailed,
  ) {
    final Widget? primary;
    if (_finished) {
      primary = FilledButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: const Text('Back to deliveries'),
        style: _buttonStyle,
      );
    } else if (scanTarget['facility_id'] is num) {
      final facility = _text(scanTarget['name']);
      primary = FilledButton.icon(
        onPressed: _busy ? null : _scanFacility,
        icon: const Icon(Icons.qr_code_scanner, size: 20),
        label: Text(
          facility.isEmpty ? 'Scan at facility' : 'Scan at $facility',
        ),
        style: _buttonStyle,
      );
    } else if (scanType != null && !taskFailed) {
      final needsProof =
          scanType == 'delivered' && _order['delivery_proof_required'] == true;
      primary = FilledButton.icon(
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.qr_code_scanner, size: 20),
        label: Text(
          needsProof
              ? 'Scan and add delivery proof'
              : riderScanLabelFor(scanType),
        ),
        style: _buttonStyle,
      );
    } else {
      primary = null;
    }
    if (primary == null) return null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: _C.shadow, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: SizedBox(width: double.infinity, height: 54, child: primary),
        ),
      ),
    );
  }

  ButtonStyle get _buttonStyle => FilledButton.styleFrom(
    backgroundColor: _C.prune,
    disabledBackgroundColor: _C.disabled,
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white,
    elevation: 0,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
  );

  // ── Route node data ──────────────────────────────────────────────
  List<_RouteNode> _routeNodes(Map<String, dynamic> order) {
    final route = _map(order['planned_route']);
    final stop = _map(order['stop']);
    final hub = _text(order['pickup_center']);

    if (order['assignment'] == 'linehaul') {
      final origin = _text(route['origin_main_hub']);
      final destination = _text(route['destination_main_hub']);
      final nodes = <_RouteNode>[
        _RouteNode(
          color: _C.raisin,
          icon: Icons.warehouse_outlined,
          label: 'Origin Main Hub',
          title: origin.isEmpty ? hub : origin,
          subtitle: 'Where the trip starts',
        ),
      ];
      final checkpoints = route['checkpoints'];
      if (checkpoints is List) {
        for (final checkpoint in checkpoints) {
          final data = _map(checkpoint);
          final name = _text(data['name']);
          if (name.isEmpty) continue;
          nodes.add(
            _RouteNode(
              color: _C.brique,
              icon: Icons.location_on_rounded,
              label: 'Facility stop',
              title: name,
              subtitle: [
                _text(data['municipality']),
                _text(data['province']),
              ].where((value) => value.isNotEmpty).join(' · '),
            ),
          );
        }
      }
      nodes.add(
        _RouteNode(
          color: _C.prune,
          icon: Icons.flag_outlined,
          label: 'Destination Main Hub',
          title: destination.isEmpty
              ? (_text(order['destination_center']).isEmpty
                    ? 'Set by Logistics'
                    : _text(order['destination_center']))
              : destination,
          subtitle: 'Final Main Hub on this route',
        ),
      );
      return nodes;
    }

    final stopTitle = _text(stop['name']);
    final stopAddress = _text(stop['address']);
    if (order['assignment'] == 'pickup') {
      return [
        _RouteNode(
          color: _C.raisin,
          icon: Icons.storefront_outlined,
          label: 'Pickup',
          title: stopTitle.isEmpty ? 'Seller' : stopTitle,
          subtitle: stopAddress.isEmpty ? 'Address unavailable' : stopAddress,
        ),
        _RouteNode(
          color: _C.brique,
          icon: Icons.warehouse_outlined,
          label: 'Origin hub',
          title: hub.isEmpty ? 'Logistics hub' : hub,
          subtitle: 'Sorting hub the parcel goes to next',
        ),
      ];
    }

    final facility = _map(order['dispatch_facility']);
    final facilityName = _text(facility['name']);
    return [
      _RouteNode(
        color: _C.raisin,
        icon: Icons.warehouse_outlined,
        label: 'Dispatch station',
        title: facilityName.isEmpty
            ? (hub.isEmpty ? 'Logistics hub' : hub)
            : facilityName,
        subtitle: [
          _text(facility['municipality']),
          _text(facility['province']),
          _text(facility['address']),
        ].where((value) => value.isNotEmpty).join(' · '),
      ),
      _RouteNode(
        color: _C.brique,
        icon: Icons.location_on_rounded,
        label: 'Drop-off',
        title: stopTitle.isEmpty ? 'Recipient' : stopTitle,
        subtitle: stopAddress.isEmpty ? 'Address unavailable' : stopAddress,
      ),
    ];
  }

  _StageStyle _stageStyle(RiderStage stage) => _StageStyle.of(stage);
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StageStyle {
  final Color fg, bg;
  final IconData icon;

  const _StageStyle(this.fg, this.bg, this.icon);

  static _StageStyle of(RiderStage stage) => switch (stage) {
    RiderStage.readyForPickup => const _StageStyle(
      Color(0xFF8A6D1A),
      _C.goldSoft,
      Icons.shopping_bag_outlined,
    ),
    RiderStage.onTheWayToHub => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.local_shipping_rounded,
    ),
    RiderStage.forDelivery => const _StageStyle(
      _C.raisin,
      _C.raisinSoft,
      Icons.inventory_2_outlined,
    ),
    RiderStage.onTheWayToBuyer => const _StageStyle(
      _C.brique,
      _C.briqueSoft,
      Icons.near_me_rounded,
    ),
    RiderStage.linehaul => const _StageStyle(
      _C.prune,
      _C.raisinSoft,
      Icons.local_shipping_outlined,
    ),
    RiderStage.other => const _StageStyle(
      _C.muted,
      Color(0xFFF1EEF1),
      Icons.inventory_2_outlined,
    ),
  };
}

class _RouteNode {
  final Color color;
  final IconData icon;
  final String label, title, subtitle;

  const _RouteNode({
    required this.color,
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
  });
}

class _RouteStop extends StatelessWidget {
  final _RouteNode node;

  const _RouteStop({required this.node});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: node.color, shape: BoxShape.circle),
          child: Icon(node.icon, color: Colors.white, size: 11),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.label,
                style: const TextStyle(color: _C.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                node.title,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (node.subtitle.isNotEmpty)
                Text(
                  node.subtitle,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _Card({required this.child, this.borderColor = _C.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _C.brique,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _C.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parcel label scanner (Android/iOS camera, Linux zbarcam)
// ─────────────────────────────────────────────────────────────────────────────
class _ParcelScanner extends StatefulWidget {
  const _ParcelScanner({required this.trackingNumber});
  final String trackingNumber;

  @override
  State<_ParcelScanner> createState() => _ParcelScannerState();
}

class _ParcelScannerState extends State<_ParcelScanner> {
  final MobileScannerController? _mobileCamera =
      defaultTargetPlatform == TargetPlatform.linux
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
        '--set',
        'qrcode.enable=1',
        '--set',
        'code128.enable=1',
      ]);
      if (!mounted) {
        camera.kill();
        return;
      }
      _linuxCamera = camera;
      setState(
        () => _cameraMessage =
            'Point the laptop camera at the printed QR or barcode. The camera preview opens in a separate window.',
      );
      _linuxCodes = camera.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((code) {
            if (_found || !mounted) return;
            if (code.trim() == widget.trackingNumber) {
              _found = true;
              Navigator.pop(context, widget.trackingNumber);
            } else if (code.trim().isNotEmpty) {
              setState(
                () => _cameraMessage =
                    'That code belongs to a different parcel. Scan the assigned label.',
              );
            }
          });
      final exitCode = await camera.exitCode;
      if (mounted && !_found) {
        setState(
          () => _cameraMessage =
              'Camera reader closed (exit $exitCode). Check webcam access and retry.',
        );
      }
    } on ProcessException {
      if (mounted) {
        setState(
          () => _cameraMessage =
              'Linux camera reader is missing. Install Fedora package zbar, then reopen this scan.',
        );
      }
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
    body: Column(
      children: [
        Expanded(
          child: defaultTargetPlatform == TargetPlatform.linux
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_cameraMessage, textAlign: TextAlign.center),
                  ),
                )
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
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Scan the barcode or QR on ${widget.trackingNumber}. Only this assigned parcel will be accepted.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
