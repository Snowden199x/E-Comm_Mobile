import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
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
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _loadingLocation = true;
  StreamSubscription<Position>? _locationStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Check and request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      // Permission permanently denied — use fallback
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(14.2793, 121.4110);
          _loadingLocation = false;
        });
      }
      return;
    }

    // Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(14.2793, 121.4110);
          _loadingLocation = false;
        });
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
        _fitBounds();
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
              }
            },
            onError: (_) {
              if (mounted && _currentLocation == null) {
                setState(() {
                  _currentLocation = const LatLng(14.2793, 121.4110);
                  _loadingLocation = false;
                });
              }
            },
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(14.2793, 121.4110);
          _loadingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fitBounds() {
    if (_currentLocation == null) return;
    final bounds = LatLngBounds.fromPoints([
      _currentLocation!,
      widget.destination,
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
          : Stack(
              children: [
                // ── Map ───────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? widget.destination,
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
                    if (_currentLocation != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_currentLocation!, widget.destination],
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
                        Marker(
                          point: widget.destination,
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
