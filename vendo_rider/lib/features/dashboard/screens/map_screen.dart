import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  /// The drop-off destination coordinates
  final LatLng destination;
  final String destinationLabel;

  const MapScreen({
    super.key,
    required this.destination,
    required this.destinationLabel,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _loadingLocation = true;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      // Use a fallback location (Metro Manila area) if denied
      setState(() {
        _currentLocation = const LatLng(14.5995, 120.9842);
        _loadingLocation = false;
        _buildMapElements();
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
        _buildMapElements();
      });
      _fitBounds();
    } catch (_) {
      setState(() {
        _currentLocation = const LatLng(14.5995, 120.9842);
        _loadingLocation = false;
        _buildMapElements();
      });
    }
  }

  void _buildMapElements() {
    if (_currentLocation == null) return;

    _markers = {
      // Current location marker
      Marker(
        markerId: const MarkerId('current'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      // Destination marker
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        infoWindow: InfoWindow(
          title: 'Drop-off',
          snippet: widget.destinationLabel,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    // Simple straight-line polyline (replace with Directions API for real route)
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_currentLocation!, widget.destination],
        color: const Color(0xFF2D1B3D),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  void _fitBounds() {
    if (_mapController == null || _currentLocation == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _currentLocation!.latitude < widget.destination.latitude
            ? _currentLocation!.latitude
            : widget.destination.latitude,
        _currentLocation!.longitude < widget.destination.longitude
            ? _currentLocation!.longitude
            : widget.destination.longitude,
      ),
      northeast: LatLng(
        _currentLocation!.latitude > widget.destination.latitude
            ? _currentLocation!.latitude
            : widget.destination.latitude,
        _currentLocation!.longitude > widget.destination.longitude
            ? _currentLocation!.longitude
            : widget.destination.longitude,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _goToMyLocation() {
    if (_currentLocation == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1B3D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Route Map',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────
          _loadingLocation
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2D1B3D),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Getting your location…',
                        style: TextStyle(color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? widget.destination,
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitBounds();
                  },
                ),

          // ── Route info card at bottom ─────────────────────
          if (!_loadingLocation)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Pickup row
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Vendo Warehouse, Quezon City',
                            style: TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Dashed line
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        top: 3,
                        bottom: 3,
                      ),
                      child: Column(
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 2,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            color: const Color(0xFFDDDDDD),
                          ),
                        ),
                      ),
                    ),

                    // Drop-off row
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFE53935),
                          size: 14,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.destinationLabel,
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // My location button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _goToMyLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('Center on my location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2D1B3D),
                          side: const BorderSide(
                            color: Color(0xFF2D1B3D),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── My location FAB ────────────────────────────────
          if (!_loadingLocation)
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.small(
                heroTag: 'locate',
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: _goToMyLocation,
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF2D1B3D),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
