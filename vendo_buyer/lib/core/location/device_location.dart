import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';

/// A device-location attempt that could not produce an address, with a message
/// ready to show the buyer (same wording as the web checkout).
class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the device's current position and resolves it to a place, exactly what
/// "Use this device's location" does on the web checkout.
Future<ApiGeoPlace> devicePinnedPlace() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const DeviceLocationException(
      'Turn on location services on this device to use your location.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const DeviceLocationException(
      'Allow location access in Settings to use the device location.',
    );
  }
  if (permission == LocationPermission.deniedForever) {
    throw const DeviceLocationException(
      'Location access is blocked for Vendo. Allow it in your device settings.',
    );
  }

  final Position position;
  try {
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } on TimeoutException {
    throw const DeviceLocationException(
      'Could not get the device location. Try again where the address is.',
    );
  }

  final place = await BuyerApi.instance.geoReverse(
    position.latitude,
    position.longitude,
  );
  if (place == null) {
    throw const DeviceLocationException(
      'No address was found for your location. Move the pin a little and try again.',
    );
  }
  return place;
}
