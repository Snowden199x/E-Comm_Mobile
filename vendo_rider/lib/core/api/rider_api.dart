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
    if (configuredUrl.isNotEmpty) return configuredUrl.replaceFirst(RegExp(r'/+$'), '');

    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000/api/v1/rider';
    }

    return 'https://vendo-ph.app/api/v1/rider';
  }
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> hasToken() async => (await _storage.read(key: 'rider_token')) != null;
  Future<String?> riderName() => _storage.read(key: 'rider_name');
  Future<String?> centerName() => _storage.read(key: 'center_name');

  Future<Map<String, dynamic>> locations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/locations'),
      headers: {'Accept': 'application/json'},
    )
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> barangays(String cityCode) async {
    final response = await http.get(
      Uri.parse('$baseUrl/locations/$cityCode/barangays'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> register(
    Map<String, String> fields,
    Map<String, String> documentPaths,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/register'));
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    for (final entry in documentPaths.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    return _body(await http.Response.fromStream(streamed));
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'device_name': 'Vendo Rider mobile',
      }),
    ).timeout(const Duration(seconds: 20));
    final data = _body(response);
    await _storage.write(key: 'rider_token', value: data['token'] as String);
    await _storage.write(
      key: 'rider_name',
      value: (data['rider'] as Map<String, dynamic>)['name'] as String?,
    );
    await _storage.write(
      key: 'center_name',
      value: (data['logistics_center'] as Map<String, dynamic>)['name'] as String?,
    );
  }

  Future<List<Map<String, dynamic>>> assignments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assignments'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    final data = _body(response);
    return (data['assignments'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> scan(
    String trackingNumber,
    String scanType,
    String scanKey,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scans'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'tracking_number': trackingNumber,
        'scan_type': scanType,
        'scan_key': scanKey,
      }),
    ).timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<String?> pendingScanKey(String trackingNumber, String scanType) =>
      _storage.read(key: 'scan:$trackingNumber:$scanType');

  Future<void> saveScanKey(String trackingNumber, String scanType, String key) =>
      _storage.write(key: 'scan:$trackingNumber:$scanType', value: key);

  Future<void> clearScanKey(String trackingNumber, String scanType) =>
      _storage.delete(key: 'scan:$trackingNumber:$scanType');

  Future<void> clearSession() => _storage.deleteAll();

  Future<void> logout() async {
    final response = await http.post(
      Uri.parse('$baseUrl/logout'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 20));
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
          : (data['message']?.toString() ?? 'Request failed. Please try again.');
      throw RiderApiException(detail, response.statusCode);
    }
    return data;
  }
}
