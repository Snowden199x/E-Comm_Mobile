import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

class MapScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationLabel;

  const MapScreen({
    super.key,
    this.destination,
    this.destinationLabel,
  });

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _destination;
  String? _destinationLabel;
  String? _assignmentError;
  bool _loadingLocation = true;
  bool _loadingAssignment = true;
  bool _didFitBounds = false;
  StreamSubscription<Position>? _locationStream;

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
    _destinationLabel = widget.destinationLabel;
    _initLocation();
    _loadDeliveryDestination();
  }

  Future<void> _loadDeliveryDestination() async {
    if (widget.destination != null) {
      if (mounted) setState(() => _loadingAssignment = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loadingAssignment = true;
        _destination = null;
        _destinationLabel = null;
        _assignmentError = null;
      });
    }
    _didFitBounds = false;

    try {
      final payload = await RiderApi.instance.assignmentDashboard();
      final assignments = (payload['assignments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['assignment'] == 'delivery')
          .toList();
      assignments.sort((a, b) {
        final aActive = a['status'] == 'out_for_delivery' ? 0 : 1;
        final bActive = b['status'] == 'out_for_delivery' ? 0 : 1;
        return aActive.compareTo(bActive);
      });

      final stop = assignments.isEmpty
          ? null
          : assignments.first['stop'] as Map<String, dynamic>?;
      final latitude = double.tryParse('${stop?['latitude']}');
      final longitude = double.tryParse('${stop?['longitude']}');
      if (!mounted) return;
      setState(() {
        _destinationLabel = stop?['address']?.toString();
        if (latitude != null && longitude != null) {
          _destination = LatLng(latitude, longitude);
        }
        _loadingAssignment = false;
      });
      _maybeFitBounds();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingAssignment = false;
          _assignmentError = 'Could not load the assigned delivery. Tap Map again to retry.';
        });
        _maybeFitBounds();
      }
    }
  }

  void refreshDestination() => _loadDeliveryDestination();

  Future<void> _initLocation() async {
    // Check and request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
      return;
    }

    // Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services on your device.'),
          ),
        );
      }
      return;
    }

    try {
      // Get last known position immediately for fast first render
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _currentLocation = LatLng(last.latitude, last.longitude);
          _loadingLocation = false;
        });
        _maybeFitBounds();
      }

      // Then stream live updates
      _locationStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // update every 10 metres
            ),
          ).listen(
            (pos) {
              if (mounted) {
                setState(() {
                  _currentLocation = LatLng(pos.latitude, pos.longitude);
                  _loadingLocation = false;
                });
                _maybeFitBounds();
              }
            },
            onError: (_) {
              if (mounted && _currentLocation == null) {
                setState(() => _loadingLocation = false);
              }
            },
          );
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _maybeFitBounds() {
    if (_currentLocation == null || _didFitBounds || _loadingAssignment) return;
    _didFitBounds = true;
    if (_destination == null) {
      _mapController.move(_currentLocation!, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints([
      _currentLocation!,
      _destination!,
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
  }

  void _goToMyLocation() {
    if (_currentLocation == null) return;
    _mapController.move(_currentLocation!, 16);
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
      body: _loadingLocation
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
          : _currentLocation == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Enable location access to show your position. Vendo does not have delivery coordinates for this route yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Stack(
              children: [
                // ── Map ───────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 14,
                  ),
                  children: [
                    // OpenStreetMap tile layer — free, no key needed
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.vendo_rider',
                    ),

                    // Route line
                    if (_currentLocation != null && _destination != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_currentLocation!, _destination!],
                            color: const Color(0xFF2D1B3D),
                            strokeWidth: 4,
                          ),
                        ],
                      ),

                    // Markers
                    MarkerLayer(
                      markers: [
                        // Current location — blue
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x44000000),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_pin_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        // Destination — red
                        if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 40,
                          height: 48,
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 10,
                                color: const Color(0xFFE53935),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Attribution (required by OSM)
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                // ── My location FAB ────────────────────────────
                Positioned(
                  right: 16,
                  bottom: 180,
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

                // ── Bottom info card ───────────────────────────
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
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
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
                        Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDDDDD),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

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
                                'Your current location',
                                style: TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                _loadingAssignment
                                    ? 'Loading your assigned delivery…'
                                    : (_destinationLabel ?? _assignmentError ?? 'No delivery address is assigned to this Rider account.'),
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _goToMyLocation,
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 18,
                            ),
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
              ],
            ),
    );
  }
}
