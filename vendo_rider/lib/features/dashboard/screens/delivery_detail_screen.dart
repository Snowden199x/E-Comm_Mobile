import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendo_rider/features/dashboard/screens/map_screen.dart';

const _kDestination = LatLng(14.2789, 121.4244);
const _kDestinationLabel = 'Brgy. Bubukal, Santa Cruz, Laguna';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the other screens
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
  static const disabled = Color(0xFFD9D2DA);
  static const shadow = Color(0x1A412143);
}

const double _radius = 16;

/// The two photos a rider must add before confirming
enum _ProofSlot { parcel, delivered }

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  String? _parcelPhotoPath; // photo 1: the parcel
  String? _deliveredPhotoPath; // photo 2: the parcel at the buyer
  bool _confirmed = false;
  bool _showMapPreview = false;
  LatLng? _currentLocation;
  final MapController _previewMapCtrl = MapController();

  @override
  void dispose() {
    _previewMapCtrl.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────
  Future<void> _loadLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _currentLocation = const LatLng(14.2793, 121.4110),
        ); // Santa Cruz, Laguna fallback
      }
    }
  }

  void _toggleMap() {
    HapticFeedback.selectionClick();
    if (!_showMapPreview) {
      _loadLocation();
    }
    setState(() => _showMapPreview = !_showMapPreview);
  }

  void _openFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MapScreen(
          destination: _kDestination,
          destinationLabel: _kDestinationLabel,
        ),
      ),
    );
  }

  // ── Proof photos (two: the parcel, and the parcel at the buyer) ──
  String? _pathFor(_ProofSlot slot) =>
      slot == _ProofSlot.parcel ? _parcelPhotoPath : _deliveredPhotoPath;

  String get _missingHint {
    if (_parcelPhotoPath == null && _deliveredPhotoPath == null) {
      return 'Add both photos to confirm this delivery.';
    }
    if (_parcelPhotoPath == null) {
      return 'Add the parcel photo to confirm this delivery.';
    }
    return 'Add the delivered-to-buyer photo to confirm this delivery.';
  }

  Future<void> _pickProof(ImageSource source, _ProofSlot slot) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      if (slot == _ProofSlot.parcel) {
        _parcelPhotoPath = file.path;
      } else {
        _deliveredPhotoPath = file.path;
      }
    });
  }

  void _takeProofPhoto(_ProofSlot slot) {
    final isParcel = slot == _ProofSlot.parcel;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          20 + MediaQuery.of(sheetContext).padding.bottom,
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
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isParcel ? 'Photo of the Parcel' : 'Parcel Delivered to Buyer',
              style: const TextStyle(
                color: _C.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isParcel
                  ? 'Take or upload a clear photo of the parcel'
                  : 'Take or upload a photo of the parcel at the buyer',
              style: const TextStyle(color: _C.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _SourceTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take a Photo',
              subtitle: isParcel
                  ? 'Capture the parcel you are delivering'
                  : 'Capture the parcel after handing it over',
              onTap: () {
                Navigator.pop(sheetContext);
                _pickProof(ImageSource.camera, slot);
              },
            ),
            const SizedBox(height: 12),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Select an existing photo',
              onTap: () {
                Navigator.pop(sheetContext);
                _pickProof(ImageSource.gallery, slot);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm ──────────────────────────────────────────────────────
  void _confirmDelivery() {
    HapticFeedback.mediumImpact();
    setState(() => _confirmed = true);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          28 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: _C.raisinSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _C.raisin,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delivery Confirmed!',
              style: TextStyle(
                color: _C.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Order #VD-00125 has been marked as delivered.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.muted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _C.raisinSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '₱ 85.00 added to your earnings',
                style: TextStyle(
                  color: _C.prune,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext); // close this sheet
                  Navigator.pop(context); // leave the details screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.prune,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Screen ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canConfirm = _parcelPhotoPath != null && _deliveredPhotoPath != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.background,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRouteSection(),
                    const SizedBox(height: 24),
                    _buildCustomerSection(),
                    const SizedBox(height: 24),
                    _buildItemsSection(),
                    const SizedBox(height: 24),
                    _buildProofSection(canConfirm),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildConfirmBar(canConfirm),
      ),
    );
  }

  // ── Dark header: back button + order summary ─────────────────────
  Widget _buildHeader() {
    final topInset = MediaQuery.of(context).padding.top;

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
                onTap: () => Navigator.pop(context),
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
                'Delivery Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Glass-style order card (same look as the other headers)
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order',
                        style: TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '#VD-00125',
                        style: TextStyle(
                          color: _C.lin,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xB3FFFFFF),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Today, 11:30 AM',
                            style: TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _C.brique,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'On the way',
                    style: TextStyle(
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

  // ── Route ────────────────────────────────────────────────────────
  Widget _buildRouteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Route')),
            GestureDetector(
              onTap: _toggleMap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _C.raisinSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMapPreview ? Icons.map_rounded : Icons.map_outlined,
                      size: 15,
                      color: _C.prune,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showMapPreview ? 'Hide map' : 'Show map',
                      style: const TextStyle(
                        color: _C.prune,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RouteStop(
                dotColor: _C.raisin,
                icon: Icons.circle,
                label: 'Pickup',
                address: 'Vendo Warehouse, Quezon City',
              ),
              Container(
                width: 2,
                height: 20,
                margin: const EdgeInsets.only(left: 9, top: 3, bottom: 3),
                color: _C.border,
              ),
              const _RouteStop(
                dotColor: _C.brique,
                icon: Icons.location_on_rounded,
                label: 'Drop-off',
                address: _kDestinationLabel,
              ),
              if (_showMapPreview) ...[
                const SizedBox(height: 16),
                _buildMapPreview(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _previewMapCtrl,
              options: MapOptions(
                initialCenter: _currentLocation ?? _kDestination,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.vendo_rider',
                ),
                if (_currentLocation != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_currentLocation!, _kDestination],
                        color: _C.prune,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 30,
                        height: 30,
                        child: _MapPin(
                          color: _C.raisin,
                          icon: Icons.person_pin_rounded,
                        ),
                      ),
                    Marker(
                      point: _kDestination,
                      width: 30,
                      height: 30,
                      child: _MapPin(
                        color: _C.brique,
                        icon: Icons.location_on_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Full map button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _openFullMap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _C.prune,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x44000000), blurRadius: 8),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Full Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Customer ─────────────────────────────────────────────────────
  Widget _buildCustomerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Customer'),
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
                child: const Icon(
                  Icons.person_rounded,
                  color: _C.raisin,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedro Bautista',
                      style: TextStyle(
                        color: _C.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '+63 912 345 6789',
                      style: TextStyle(color: _C.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _ActionButton(
                icon: Icons.call_rounded,
                filled: true,
                onTap: () {}, // TODO: start a phone call
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                filled: false,
                onTap: () {}, // TODO: open chat / SMS
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Order items ──────────────────────────────────────────────────
  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Order Items'),
        const SizedBox(height: 12),
        const _Card(
          child: Column(
            children: [
              _OrderItem(name: 'Wireless Earbuds', qty: '1', price: '₱ 650'),
              Divider(height: 1, thickness: 1, color: _C.border),
              _OrderItem(name: 'Phone Case', qty: '2', price: '₱ 180'),
              Divider(height: 1, thickness: 1, color: _C.border),
              SizedBox(height: 12),
              _TotalRow(label: 'Delivery Fee', value: '₱ 85'),
              SizedBox(height: 10),
              _TotalRow(label: 'Total', value: '₱ 915', bold: true),
            ],
          ),
        ),
      ],
    );
  }

  // ── Proof of delivery: two photos needed ─────────────────────────
  Widget _buildProofSection(bool canConfirm) {
    final added =
        (_parcelPhotoPath != null ? 1 : 0) +
        (_deliveredPhotoPath != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Proof of Delivery')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: canConfirm ? _C.raisinSoft : _C.briqueSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                canConfirm ? 'Added' : '$added of 2 added',
                style: TextStyle(
                  color: canConfirm ? _C.raisin : _C.brique,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Card(
          borderColor: canConfirm ? _C.raisin : _C.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Two photos are needed before you can confirm this delivery.',
                style: TextStyle(color: _C.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              _buildPhotoStep(
                slot: _ProofSlot.parcel,
                step: '1',
                title: 'Photo of the parcel',
                hint: 'Take a clear photo of the parcel you are delivering.',
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, thickness: 1, color: _C.border),
              const SizedBox(height: 20),
              _buildPhotoStep(
                slot: _ProofSlot.delivered,
                step: '2',
                title: 'Parcel delivered to the buyer',
                hint:
                    'Take a photo of the parcel after handing it to the buyer.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // One numbered step: title, short hint, and the photo box
  Widget _buildPhotoStep({
    required _ProofSlot slot,
    required String step,
    required String title,
    required String hint,
  }) {
    final path = _pathFor(slot);
    final hasPhoto = path != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasPhoto ? _C.prune : _C.raisinSoft,
                shape: BoxShape.circle,
              ),
              child: hasPhoto
                  ? const Icon(Icons.check_rounded, color: _C.lin, size: 15)
                  : Text(
                      step,
                      style: const TextStyle(
                        color: _C.raisin,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 2, bottom: 12),
          child: Text(
            hint,
            style: const TextStyle(color: _C.muted, fontSize: 12, height: 1.4),
          ),
        ),
        GestureDetector(
          onTap: () => _takeProofPhoto(slot),
          child: path != null
              ? _buildPhotoPreview(path)
              : _buildPhotoPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: _C.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _C.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: _C.raisin,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to take or upload photo',
            style: TextStyle(
              color: _C.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(String path) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(153),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Retake',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.prune,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: _C.lin, size: 14),
                SizedBox(width: 4),
                Text(
                  'Photo added',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Confirm bar: always visible at the bottom ────────────────────
  Widget _buildConfirmBar(bool canConfirm) {
    final enabled = canConfirm && !_confirmed;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canConfirm)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: _C.brique,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _missingHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _C.muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: enabled ? _confirmDelivery : null,
                  icon: Icon(
                    _confirmed
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 20,
                  ),
                  label: Text(_confirmed ? 'Delivered' : 'Confirm Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.prune,
                    disabledBackgroundColor: _C.disabled,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Flat white card with a thin border (same as the other screens)
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

class _RouteStop extends StatelessWidget {
  final Color dotColor;
  final IconData icon;
  final String label, address;

  const _RouteStop({
    required this.dotColor,
    required this.icon,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 11),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _C.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: filled ? _C.prune : _C.raisinSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: filled ? Colors.white : _C.prune, size: 20),
      ),
    );
  }
}

class _OrderItem extends StatelessWidget {
  final String name, qty, price;

  const _OrderItem({
    required this.name,
    required this.qty,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _C.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _C.raisin,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text('x$qty', style: const TextStyle(color: _C.muted, fontSize: 13)),
          const SizedBox(width: 16),
          Text(
            price,
            style: const TextStyle(
              color: _C.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: bold ? _C.ink : _C.muted,
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: bold ? _C.prune : _C.ink,
            fontSize: bold ? 18 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.background,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _C.raisinSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _C.raisin, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _C.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
