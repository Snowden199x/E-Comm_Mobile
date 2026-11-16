import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/core/location/device_location.dart';

/// Map pin picker for a delivery address, the app half of the web's Geoapify
/// dialog: search a place or tap the map, see the address at the pin, or jump to
/// the device location. The API supplies the tiles, the search and the reverse
/// geocoding, so the app never holds the provider key.
class AddressPinScreen extends StatefulWidget {
  const AddressPinScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  /// Existing pin to reopen, when the buyer is changing one they already set.
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<AddressPinScreen> createState() => _AddressPinScreenState();
}

class _AddressPinScreenState extends State<AddressPinScreen> {
  static const _plum = Color(0xFF402143);
  static const _plumMid = Color(0xFF52245B);
  static const _accent = Color(0xFF805487);
  static const _ink = Color(0xFF2B1730);
  static const _muted = Color(0xFF7A6A7E);
  static const _lite = Color(0xFF8A7A8E);
  static const _fieldBorder = Color(0xFFE5DCE7);
  static const _green = Color(0xFF2E6B46);
  static const _red = Color(0xFFA32B43);

  final MapController _map = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  ApiGeoMapConfig? _config;
  String? _configError;
  LatLng? _pin;
  ApiGeoPlace? _place;
  List<ApiGeoPlace> _results = const [];
  String? _error;
  String? _searchError;
  bool _searching = false;
  bool _locating = false;
  bool _filling = false;

  /// Guards against an older reverse-geocode response overwriting a newer pin.
  int _ping = 0;

  bool get _hasInitialPin =>
      widget.initialLatitude != null && widget.initialLongitude != null;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _configError = null;
      _config = null;
    });
    try {
      final config = await BuyerApi.instance.geoConfig();
      if (!mounted) return;
      setState(() => _config = config);
      if (_hasInitialPin) {
        _moveTo(
          LatLng(widget.initialLatitude!, widget.initialLongitude!),
          zoom: 17,
          geocode: false,
        );
        _reverseGeocode(widget.initialLatitude!, widget.initialLongitude!);
      }
    } on BuyerApiException catch (e) {
      if (mounted) setState(() => _configError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _configError =
              'The map could not load. Check your connection and try again.',
        );
      }
    }
  }

  void _moveTo(LatLng point, {double zoom = 17, bool geocode = true}) {
    setState(() {
      _pin = point;
      _error = null;
    });
    _map.move(point, zoom);
    if (geocode) _reverseGeocode(point.latitude, point.longitude);
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    final ping = ++_ping;
    setState(() {
      _filling = true;
      _error = null;
    });
    try {
      final place = await BuyerApi.instance.geoReverse(latitude, longitude);
      if (!mounted || ping != _ping) return;
      setState(() {
        _place = place;
        if (place == null) {
          _error =
              'No address was found for this pin. Move it a little and try again.';
        }
      });
    } on BuyerApiException catch (e) {
      if (!mounted || ping != _ping) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || ping != _ping) return;
      setState(() => _error = 'Address lookup failed. Check your connection.');
    } finally {
      if (mounted && ping == _ping) setState(() => _filling = false);
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 3) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await BuyerApi.instance.geoSearch(query);
      if (!mounted || _searchCtrl.text.trim() != query) return;
      setState(() => _results = results);
    } on BuyerApiException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _searchError =
              'Address search is unavailable right now. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(ApiGeoPlace place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _place = place;
      _error = null;
    });
    _searchCtrl.text = place.formatted;
    _moveTo(LatLng(place.latitude, place.longitude), geocode: false);
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final place = await devicePinnedPlace();
      if (!mounted) return;
      setState(() => _place = place);
      _moveTo(LatLng(place.latitude, place.longitude), geocode: false);
    } on DeviceLocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not get the device location. Try again where the address is.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _save() {
    final place = _place;
    final pin = _pin;
    if (place == null || pin == null) {
      setState(() => _error = 'Search a place or tap the map on the address.');
      return;
    }
    Navigator.pop(
      context,
      ApiGeoPlace(
        latitude: pin.latitude,
        longitude: pin.longitude,
        formatted: place.formatted,
        street: place.street,
        barangay: place.barangay,
        city: place.city,
        cityCode: place.cityCode,
        province: place.province,
        provinceCode: place.provinceCode,
        postcode: place.postcode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EDF4),
      appBar: AppBar(
        backgroundColor: _plum,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pin this delivery address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'The address fields stay editable afterwards.',
              style: TextStyle(fontSize: 11, color: Color(0xFFDCCDE0)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _config == null
            ? _mapPlaceholder()
            : Stack(
                children: [
                  Positioned.fill(child: _mapView(_config!)),
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: _searchPanel(),
                  ),
                  Positioned(bottom: 0, left: 0, right: 0, child: _pinPanel()),
                ],
              ),
      ),
    );
  }

  Widget _mapPlaceholder() {
    return Center(
      child: _configError == null
          ? const CircularProgressIndicator(color: _plum)
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 40, color: _lite),
                  const SizedBox(height: 10),
                  Text(
                    _configError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadConfig,
                    style: OutlinedButton.styleFrom(foregroundColor: _plumMid),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _mapView(ApiGeoMapConfig config) {
    final pin = _pin;
    final initial =
        pin ?? LatLng(config.defaultLatitude, config.defaultLongitude);
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: initial,
        initialZoom: pin == null ? 6 : 17,
        minZoom: 4,
        maxZoom: 19,
        onTap: (_, point) => _moveTo(point),
      ),
      children: [
        TileLayer(
          urlTemplate: config.tileUrl,
          userAgentPackageName: 'com.example.vendo_buyer',
          maxZoom: 19,
        ),
        if (pin != null)
          MarkerLayer(
            markers: [
              Marker(
                point: pin,
                width: 46,
                height: 46,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.location_on,
                  size: 42,
                  color: _plum,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (config.attribution.isNotEmpty)
          RichAttributionWidget(
            attributions: [TextSourceAttribution(config.attribution)],
          ),
      ],
    );
  }

  Widget _searchPanel() {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (text) {
                final query = text.trim();
                if (query.length >= 3) _search(query);
              },
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search a street, barangay, city or landmark',
                hintStyle: const TextStyle(fontSize: 12.5, color: _lite),
                prefixIcon: const Icon(Icons.search, size: 18, color: _lite),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _results = const []);
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _accent),
                ),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Searching…',
                  style: TextStyle(fontSize: 11, color: _accent),
                ),
              ),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _searchError!,
                  style: const TextStyle(fontSize: 11, color: _red),
                ),
              ),
            if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 224),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF1E8F2)),
                  itemBuilder: (_, index) {
                    final place = _results[index];
                    return InkWell(
                      onTap: () => _selectResult(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Text(
                          place.formatted,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: _ink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pinPanel() {
    final place = _place;
    return Material(
      elevation: 8,
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ADDRESS AT THE PIN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: _lite,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              place?.formatted ??
                  (_pin == null
                      ? 'Tap the map on the address, or search above.'
                      : 'Move the pin a little to find the address.'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: place == null ? _lite : _ink,
              ),
            ),
            if (_filling)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Reading the address…',
                  style: TextStyle(fontSize: 11, color: _accent),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: _red),
                ),
              ),
            if (place != null && !_filling)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    place.line,
                    place.postcode,
                    place.city,
                    place.province,
                  ].where((part) => part.isNotEmpty).join(', '),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: _green,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useDeviceLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(
                      _locating ? 'Getting location…' : 'Use my location',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _plumMid,
                      side: const BorderSide(color: _accent),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: place == null ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _plum,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text(
                      'Use this address',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
