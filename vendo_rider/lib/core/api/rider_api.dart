import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class RiderApiException implements Exception {
  const RiderApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RiderApi {
  RiderApi._();

  static final RiderApi instance = RiderApi._();
  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('VENDO_API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000/api/v1/rider';
    }

    return 'https://vendo-ph.app/api/v1/rider';
  }

  static String get transportDriverBaseUrl =>
      baseUrl.replaceFirst(RegExp(r'/rider/?$'), '/transport-drivers');

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'rider_token')) != null;
  Future<String?> riderName() => _storage.read(key: 'rider_name');
  Future<String?> centerName() => _storage.read(key: 'center_name');
  Future<String?> riderVehicleType() =>
      _storage.read(key: 'rider_vehicle_type');

  Future<String?> transportDriverName() =>
      _storage.read(key: 'transport_driver_name');

  Future<String?> transportCompanyName() =>
      _storage.read(key: 'transport_company_name');

  Future<Map<String, dynamic>> locations() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/locations'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> barangays(String cityCode) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/locations/$cityCode/barangays'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> register(
    Map<String, String> fields,
    Map<String, String> documentPaths,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/register'),
    );
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    for (final entry in documentPaths.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    return _body(await http.Response.fromStream(streamed));
  }

  Future<void> sendRegistrationCode(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/send'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    _body(response);
  }

  Future<String> verifyRegistrationCode(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/verify'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    return _body(response)['verification_token'] as String;
  }

  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/google'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'credential': idToken,
            'device_name': 'Vendo Rider mobile',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _body(response);
    if (data['registration_required'] == true) return data;
    await _saveLogin(data);
    return data;
  }

  Future<void> sendPasswordResetCode(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/password/otp/send'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    _body(response);
  }

  Future<String> verifyPasswordResetCode(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/password/otp/verify'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    return _body(response)['reset_token'] as String;
  }

  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/password/reset'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'reset_token': token,
            'password': password,
            'password_confirmation': confirmation,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _body(response);
  }

  Future<void> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'device_name': 'Vendo Rider mobile',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _body(response);
    await _saveLogin(data);
  }

  Future<void> transportDriverLogin(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$transportDriverBaseUrl/login'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'device_name': 'Vendo Transport Driver mobile',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _body(response);
    await _storage.write(
      key: 'transport_driver_token',
      value: data['token'] as String,
    );
    await _storage.write(
      key: 'transport_driver_name',
      value: (data['driver'] as Map)['name']?.toString(),
    );
    await _storage.write(
      key: 'transport_company_name',
      value: (data['company'] as Map)['name']?.toString(),
    );
  }

  Future<List<Map<String, dynamic>>> transportDriverTrips() async {
    final response = await http
        .get(
          Uri.parse('$transportDriverBaseUrl/trips'),
          headers: await _transportDriverHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    return (_body(response)['trips'] as List<dynamic>)
        .map((trip) => Map<String, dynamic>.from(trip as Map))
        .toList();
  }

  Future<Map<String, dynamic>> updateTransportTrip(
    int tripId,
    String action,
  ) async {
    final response = await http
        .post(
          Uri.parse('$transportDriverBaseUrl/trips/$tripId/$action'),
          headers: await _transportDriverHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<void> logoutTransportDriver() async {
    final response = await http
        .post(
          Uri.parse('$transportDriverBaseUrl/logout'),
          headers: await _transportDriverHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    _body(response);
    await _storage.delete(key: 'transport_driver_token');
    await _storage.delete(key: 'transport_driver_name');
    await _storage.delete(key: 'transport_company_name');
  }

  Future<void> _saveLogin(Map<String, dynamic> data) async {
    await _storage.write(key: 'rider_token', value: data['token'] as String);
    await _storage.write(
      key: 'rider_name',
      value: (data['rider'] as Map<String, dynamic>)['name'] as String?,
    );
    final rider = data['rider'] as Map<String, dynamic>;
    final vehicleType = rider['vehicle_type']?.toString();
    if (vehicleType == null || vehicleType.isEmpty) {
      await _storage.delete(key: 'rider_vehicle_type');
    } else {
      await _storage.write(key: 'rider_vehicle_type', value: vehicleType);
    }
    await _storage.write(
      key: 'center_name',
      value:
          (data['logistics_center'] as Map<String, dynamic>)['name'] as String?,
    );
  }

  Future<List<Map<String, dynamic>>> assignments() async {
    final data = await assignmentDashboard();
    return (data['assignments'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> assignmentDashboard() async {
    final response = await http
        .get(Uri.parse('$baseUrl/assignments'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> riderNotifications() async {
    final response = await http
        .get(Uri.parse('$baseUrl/notifications'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<void> markRiderNotificationRead(int notificationId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/notifications/$notificationId/read'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    _body(response);
  }

  Future<void> markAllRiderNotificationsRead() async {
    final response = await http
        .post(Uri.parse('$baseUrl/notifications/read-all'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    _body(response);
  }

  Future<Map<String, dynamic>> earnings({bool transportDriver = false}) async {
    final base = transportDriver ? transportDriverBaseUrl : baseUrl;
    final headers = transportDriver
        ? await _transportDriverHeaders()
        : await _authHeaders();
    final response = await http
        .get(Uri.parse('$base/earnings'), headers: headers)
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> scan(
    String trackingNumber,
    String scanType,
    String scanKey,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/scans'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'tracking_number': trackingNumber,
            'scan_type': scanType,
            'scan_key': scanKey,
          }),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<Map<String, dynamic>> scanFacility(
    String trackingNumber,
    int facilityId,
    String scanKey,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/facility-scans'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'tracking_number': trackingNumber,
            'facility_id': facilityId,
            'scan_key': scanKey,
          }),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<Map<String, dynamic>> reportTaskException({
    required int taskId,
    required String reason,
    required String details,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/tasks/$taskId/exceptions'),
          headers: await _authHeaders(),
          body: jsonEncode({'reason': reason, 'details': details.trim()}),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<Map<String, dynamic>> submitDeliveryProof({
    required String trackingNumber,
    required String scanKey,
    required String recipientName,
    required String photoPath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/delivery-proofs'),
    );
    final headers = await _authHeaders();
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.fields.addAll({
      'tracking_number': trackingNumber,
      'scan_key': scanKey,
      'recipient_name': recipientName.trim(),
    });
    request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    return _body(await http.Response.fromStream(streamed));
  }

  Future<String?> pendingScanKey(String trackingNumber, String scanType) =>
      _storage.read(key: 'scan:$trackingNumber:$scanType');

  Future<void> saveScanKey(
    String trackingNumber,
    String scanType,
    String key,
  ) => _storage.write(key: 'scan:$trackingNumber:$scanType', value: key);

  Future<void> clearScanKey(String trackingNumber, String scanType) =>
      _storage.delete(key: 'scan:$trackingNumber:$scanType');

  Future<void> clearSession() => _storage.deleteAll();

  Future<void> logout() async {
    final response = await http
        .post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    _body(response);
    await _storage.deleteAll();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'rider_token');
    if (token == null) {
      throw const RiderApiException('Please sign in again.', 401);
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _transportDriverHeaders() async {
    final token = await _storage.read(key: 'transport_driver_token');
    if (token == null) {
      throw const RiderApiException('Please sign in again.', 401);
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _body(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw RiderApiException(
        'HTTP ${response.statusCode} from ${response.request?.url ?? baseUrl}. Check that this Vendo API version is running.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      final errors = data['errors'];
      final detail = errors is Map && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : (data['message']?.toString() ??
                'Request failed. Please try again.');
      throw RiderApiException(detail, response.statusCode);
    }
    return data;
  }
}
