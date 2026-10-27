import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class BuyerApiException implements Exception {
  const BuyerApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BuyerApi {
  BuyerApi._();

  static final BuyerApi instance = BuyerApi._();

  static String get baseUrl {
    const configured = String.fromEnvironment('VENDO_BUYER_API_BASE_URL');
    if (configured.isNotEmpty)
      return configured.replaceFirst(RegExp(r'/+$'), '');
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000/api/v1/buyer';
    }
    return 'https://vendo-ph.app/api/v1/buyer';
  }

  static const _storage = FlutterSecureStorage();

  // ── Token helpers ──────────────────────────────────────────────────────────
  Future<bool> hasToken() async =>
      (await _storage.read(key: 'buyer_token')) != null;
  Future<String?> buyerName() => _storage.read(key: 'buyer_name');
  Future<String?> buyerEmail() => _storage.read(key: 'buyer_email');

  Future<void> clearSession() => _storage.deleteAll();

  // ── OTP ────────────────────────────────────────────────────────────────────
  Future<void> sendOtp(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/send'),
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    _check(response);
  }

  /// Returns the verification_token string on success.
  Future<String> verifyOtp(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/verify'),
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    return _check(response)['verification_token'] as String;
  }

  // ── Registration ───────────────────────────────────────────────────────────
  Future<void> register({
    required Map<String, String> fields,
    required String validIdPath,
    String? validId2Path,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/register'),
    );
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath('valid_id', validIdPath),
    );
    if (validId2Path != null) {
      request.files.add(
        await http.MultipartFile.fromPath('valid_id_2', validId2Path),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    _check(await http.Response.fromStream(streamed));
  }

  // ── Login / logout ─────────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'device_name': 'Vendo Buyer mobile',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _check(response);
    await _saveLogin(data);
  }

  Future<void> logout() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 20));
      _check(response);
    } finally {
      await _storage.deleteAll();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final response = await http
        .get(Uri.parse('$baseUrl/me'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return _check(response);
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  Future<void> _saveLogin(Map<String, dynamic> data) async {
    await _storage.write(key: 'buyer_token', value: data['token'] as String);
    final buyer = data['buyer'] as Map<String, dynamic>;
    await _storage.write(key: 'buyer_name', value: buyer['name']?.toString());
    await _storage.write(key: 'buyer_email', value: buyer['email']?.toString());
  }

  Map<String, String> _jsonHeaders() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'buyer_token');
    if (token == null)
      throw const BuyerApiException('Please sign in again.', 401);
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _check(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw BuyerApiException(
        'HTTP ${response.statusCode}. Check that the Vendo API server is running.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      final errors = data['errors'];
      final detail = errors is Map && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : (data['message']?.toString() ??
                'Request failed. Please try again.');
      throw BuyerApiException(detail, response.statusCode);
    }
    return data;
  }
}
