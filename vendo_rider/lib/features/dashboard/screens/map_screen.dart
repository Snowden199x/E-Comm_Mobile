import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/core/offline/offline_tiles.dart';

/// One turn-by-turn instruction from the routing service.
class RouteStep {
  const RouteStep({required this.instruction, required this.distanceMeters});

  final String instruction;
  final double distanceMeters;
}

/// Road routing comes from OSRM's public API: it follows the same
/// OpenStreetMap roads the tiles show, needs no key, and returns the driving
/// line plus the turn-by-turn steps.
const String _routeEndpoint = 'https://router.project-osrm.org/route/v1/driving';

const Color _prune = Color(0xFF2D1B3D);
const Color _brique = Color(0xFFBF5E40);
const Color _raisin = Color(0xFF815488);

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

  // Road route from the routing service.
  List<LatLng> _routePoints = const [];
  List<RouteStep> _routeSteps = const [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  String? _routeError;
  bool _loadingRoute = false;
  LatLng? _routeRequestOrigin;

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
      _loadDrivingRoute(force: true);
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
      _applyAssignments(payload);
      await _loadDrivingRoute(force: true);
      _maybeFitBounds();
    } catch (_) {
      // Offline: use the delivery saved on this device, if there is one.
      final cached = await RiderApi.instance.cachedWork();
      if (cached != null) {
        _applyAssignments(cached.payload);
        await _loadDrivingRoute(force: true);
        _maybeFitBounds();
      } else if (mounted) {
        setState(() {
          _loadingAssignment = false;
          _assignmentError =
              'Could not load the assigned delivery. Tap Map again to retry.';
        });
        _maybeFitBounds();
      }
    }
  }

  /// Points the map at the first delivery in the payload — live or saved.
  void _applyAssignments(Map<String, dynamic> payload) {
    if (!mounted) return;
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
    setState(() {
      _destinationLabel = stop?['address']?.toString();
      if (latitude != null && longitude != null) {
        _destination = LatLng(latitude, longitude);
      }
      _loadingAssignment = false;
    });
  }

  void refreshDestination() => _loadDeliveryDestination();

  Future<void> _initLocation() async {
    // Check and request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
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
        _loadDrivingRoute();
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
                // Re-route only after the Rider has actually moved, so the
                // public routing service is not hammered every 10 metres.
                _loadDrivingRoute();
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

  // ── Road route ───────────────────────────────────────────────────
  /// True when the Rider has moved far enough (or this is a fresh request)
  /// that the driving route should be recalculated.
  bool _needsReroute({bool force = false}) {
    final from = _currentLocation;
    if (from == null || _destination == null) return false;
    if (force) return true;
    final origin = _routeRequestOrigin;
    if (origin == null) return true;
    final moved = const Distance().as(LengthUnit.Meter, origin, from);
    return moved >= 120;
  }

  Future<void> _loadDrivingRoute({bool force = false}) async {
    final from = _currentLocation;
    final to = _destination;
    if (from == null || to == null) return;
    if (_loadingRoute || !_needsReroute(force: force)) return;

    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });
    _routeRequestOrigin = from;
    final requestedFor = to;

    try {
      final uri = Uri.parse(
        '$_routeEndpoint/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true&alternatives=false',
      );
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const FormatException('Routing service is unavailable.');
      }
      final data = jsonDecode(response.body);
      final routes = data is Map ? (data['routes'] as List<dynamic>? ?? []) : const [];
      if (routes.isEmpty) {
        throw const FormatException('No driving route was found.');
      }
      final route = Map<String, dynamic>.from(routes.first as Map);
      final geometry = _asMap(route['geometry']);
      final points = <LatLng>[];
      for (final pair in (geometry['coordinates'] as List<dynamic>? ?? const [])) {
        if (pair is! List || pair.length < 2) continue;
        final lng = double.tryParse('${pair[0]}');
        final lat = double.tryParse('${pair[1]}');
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }
      if (points.isEmpty) {
        throw const FormatException('The routing service returned no line.');
      }

      final steps = <RouteStep>[];
      final legs = route['legs'] as List<dynamic>? ?? const [];
      for (final rawLeg in legs) {
        final leg = _asMap(rawLeg);
        for (final rawStep in (leg['steps'] as List<dynamic>? ?? const [])) {
          final step = _asMap(rawStep);
          final instruction = _stepInstruction(step);
          if (instruction.isEmpty) continue;
          steps.add(RouteStep(
            instruction: instruction,
            distanceMeters: double.tryParse('${step['distance']}') ?? 0,
          ));
        }
      }

      if (!mounted || _destination != requestedFor) return;
      setState(() {
        _routePoints = points;
        _routeSteps = steps;
        _routeDistanceMeters = double.tryParse('${route['distance']}');
        _routeDurationSeconds = double.tryParse('${route['duration']}');
        _routeError = null;
      });
      _fitRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Keep any previously drawn route; the straight line still works.
        _routeError =
            'Road route unavailable right now. Showing a straight line to the buyer.';
      });
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  /// Wording for one routing step, in the same "turn right onto X" phrasing a
  /// Rider expects from a navigation app.
  String _stepInstruction(Map<String, dynamic> step) {
    final maneuver = _asMap(step['maneuver']);
    final type = '${maneuver['type'] ?? ''}'.trim();
    final modifier = '${maneuver['modifier'] ?? ''}'
        .trim()
        .replaceAll('_', ' ');
    final road = '${step['name'] ?? ''}'.trim();
    final onto = road.isEmpty ? '' : ' onto $road';
    final turn = modifier.isEmpty ? '' : ' $modifier';

    switch (type) {
      case 'depart':
        return road.isEmpty ? 'Start driving' : 'Start on $road';
      case 'arrive':
        return road.isEmpty ? 'Arrive at the delivery pin' : 'Arrive at $road';
      case 'turn':
        return modifier.isEmpty
            ? (road.isEmpty ? 'Turn ahead' : 'Turn$onto')
            : 'Turn$turn$onto';
      case 'new name':
      case 'continue':
        return road.isEmpty ? 'Continue straight' : 'Continue$onto';
      case 'merge':
        return 'Merge$turn$onto';
      case 'fork':
        return 'Keep$turn$onto';
      case 'end of road':
        return modifier.isEmpty
            ? (road.isEmpty ? 'Turn at the end of the road' : 'Turn$onto')
            : 'Turn$turn at the end of the road';
      case 'roundabout':
      case 'rotary':
        return road.isEmpty
            ? 'Enter the roundabout'
            : 'Take the roundabout onto $road';
      case 'exit roundabout':
      case 'exit rotary':
        return road.isEmpty ? 'Exit the roundabout' : 'Exit$onto';
      case 'use lane':
        return modifier.isEmpty
            ? 'Use the correct lane'
            : 'Use the $modifier lane';
      case 'notification':
        return road.isEmpty ? '' : 'Continue$onto';
      default:
        if (road.isNotEmpty) return 'Continue$onto';
        return modifier.isEmpty ? '' : 'Continue$modifier';
    }
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints),
        padding: const EdgeInsets.fromLTRB(36, 90, 36, 260),
      ),
    );
  }

  void _maybeFitBounds() {
    if (_currentLocation == null || _didFitBounds || _loadingAssignment) {
      return;
    }
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

  // ── External navigation ──────────────────────────────────────────
  /// Hands the buyer's pin to the device's Google Maps app so the Rider gets
  /// spoken turn-by-turn guidance while driving.
  Future<void> _startNavigation() async {
    final destination = _destination;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The buyer did not share a pin for this delivery.'),
        ),
      );
      return;
    }
    final lat = destination.latitude.toStringAsFixed(6);
    final lng = destination.longitude.toStringAsFixed(6);
    final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    final candidates = <Uri>[if (!kIsWeb) ..._appNavigationUris(lat, lng), web];
    for (final uri in candidates) {
      try {
        final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (opened) return;
      } catch (_) {
        // Try the next option.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No map app is available on this device.'),
      ),
    );
  }

  List<Uri> _appNavigationUris(String lat, String lng) => switch (
        defaultTargetPlatform
      ) {
        TargetPlatform.android => [
            Uri.parse('google.navigation:q=$lat,$lng&mode=d'),
          ],
        TargetPlatform.iOS => [
            Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'),
          ],
        _ => const [],
      };

  Future<void> _showDirections() async {
    final steps = _routeSteps;
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _routeError ??
                'Directions are still loading. Wait a moment and try again.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Turn-by-turn directions',
                      style: TextStyle(
                        color: _prune,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_routeDistanceMeters != null)
                    Text(
                      '${_formatDistance(_routeDistanceMeters!)} · '
                      '${_formatDuration(_routeDurationSeconds ?? 0)}',
                      style: const TextStyle(
                        color: _raisin,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 4, 20, 24),
                itemCount: steps.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final step = steps[index];
                  final isLast = index == steps.length - 1;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isLast
                          ? Icons.flag_rounded
                          : Icons.turn_right_rounded,
                      color: isLast ? _brique : _prune,
                      size: 22,
                    ),
                    title: Text(
                      step.instruction,
                      style: const TextStyle(
                        color: Color(0xFF2A1B2C),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                    subtitle: step.distanceMeters > 0
                        ? Text(
                            _formatDistance(step.distanceMeters),
                            style: const TextStyle(
                              color: Color(0xFF8C8290),
                              fontSize: 12,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    final routePoints = _routePoints.isNotEmpty
        ? _routePoints
        : (_currentLocation != null && destination != null
            ? <LatLng>[_currentLocation!, destination]
            : const <LatLng>[]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _prune,
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
        actions: [
          IconButton(
            tooltip: 'Recalculate route',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _didFitBounds = false;
              _loadDrivingRoute(force: true);
              _maybeFitBounds();
            },
          ),
        ],
      ),
      body: _loadingLocation
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_prune),
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
                  'Allow location access to see your position and the road route to the buyer. Without it Vendo cannot draw where you are.',
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
                    // Road map tiles (roads, streets, landmarks)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.vendo_rider',
                      // Tiles viewed once stay on the device for offline routing.
                      tileProvider: OfflineTileProviders.create(),
                    ),

                    // The driving line: a white outline under the route keeps
                    // it readable over built-up road tiles.
                    if (routePoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            color: Colors.white,
                            strokeWidth: 9,
                          ),
                          Polyline(
                            points: routePoints,
                            color: _routePoints.isEmpty
                                ? _brique
                                : const Color(0xFF4285F4),
                            strokeWidth: 5,
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
                        if (destination != null)
                          Marker(
                            point: destination,
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

                // ── Route status pill ──────────────────────────
                if (_loadingRoute || _routeError != null)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (_loadingRoute)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(_prune),
                                ),
                              )
                            else
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 18,
                                color: _brique,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _loadingRoute
                                    ? 'Finding the road route to the buyer…'
                                    : _routeError!,
                                style: const TextStyle(
                                  color: Color(0xFF2A1B2C),
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── My location FAB ────────────────────────────
                Positioned(
                  right: 16,
                  bottom: 250,
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _goToMyLocation,
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: _prune,
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
                                    : (_destinationLabel ??
                                        _assignmentError ??
                                        'No delivery address is assigned to this Rider account.'),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_routeDistanceMeters != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 16,
                                color: _raisin,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_formatDistance(_routeDistanceMeters!)} · '
                                  'about ${_formatDuration(_routeDurationSeconds ?? 0)} by road',
                                  style: const TextStyle(
                                    color: _raisin,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _routeSteps.isEmpty
                                    ? null
                                    : _showDirections,
                                icon: const Icon(
                                  Icons.list_alt_rounded,
                                  size: 18,
                                ),
                                label: const Text('Directions'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _prune,
                                  side: const BorderSide(
                                    color: _prune,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: destination == null
                                    ? null
                                    : _startNavigation,
                                icon: const Icon(
                                  Icons.navigation_rounded,
                                  size: 18,
                                ),
                                label: const Text('Navigate'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _prune,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
