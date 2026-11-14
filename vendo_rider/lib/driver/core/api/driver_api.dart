import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// A failed Driver API call. [applicationStatus] is filled for a valid
/// applicant who is not approved yet, so the sign-in screen can say whether the
/// application is waiting or was rejected instead of "wrong password".
class DriverApiException implements Exception {
  const DriverApiException(
    this.message, {
    this.statusCode,
    this.applicationStatus,
    this.reviewingHub,
    this.rejectionReason,
  });

  final String message;
  final int? statusCode;
  final String? applicationStatus;
  final String? reviewingHub;
  final String? rejectionReason;

  bool get isPending => applicationStatus == 'pending';
  bool get isRejected => applicationStatus == 'rejected';

  /// The saved token is no longer accepted, so the app must sign in again.
  bool get isUnauthenticated => statusCode == 401;

  @override
  String toString() => message;
}

class DriverApi {
  DriverApi._();

  static final DriverApi instance = DriverApi._();

  /// Full base for the driver endpoints. A VENDO_API_BASE_URL that already
  /// points at another v1 API (for example `/api/v1/rider`) is switched over to
  /// `/api/v1/transport-drivers`.
  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('VENDO_API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      final trimmed = configuredUrl.replaceFirst(RegExp(r'/+$'), '');
      if (trimmed.contains('/api/v1/')) {
        return '${trimmed.replaceFirst(RegExp(r'/(transport-drivers|rider)$'), '')}/transport-drivers';
      }
      return '$trimmed/api/v1/transport-drivers';
    }

    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000/api/v1/transport-drivers';
    }

    return 'https://vendo-ph.app/api/v1/transport-drivers';
  }

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'driver_token')) != null;

  Future<String?> driverName() => _storage.read(key: 'driver_name');
  Future<String?> driverApplyLabel() =>
      _storage.read(key: 'driver_apply_label');
  Future<String?> reviewingHubName() =>
      _storage.read(key: 'driver_reviewing_hub');
  Future<String?> stationHubName() => _storage.read(key: 'driver_station_hub');

  /// The last email used to apply, so the status check can prefill it.
  Future<String?> savedApplicationEmail() =>
      _storage.read(key: 'driver_application_email');

  Future<void> saveApplicationEmail(String email) =>
      _storage.write(key: 'driver_application_email', value: email.trim());

  Future<Map<String, dynamic>> hubs() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/province-hubs'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<Map<String, dynamic>> locations() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/locations'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<Map<String, dynamic>> barangays(String cityCode) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/locations/$cityCode/barangays'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
  }

  Future<void> sendRegistrationCode(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/send'),
          headers: _jsonHeaders,
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 25));
    _body(response);
  }

  Future<String> verifyRegistrationCode(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/verify'),
          headers: _jsonHeaders,
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response)['verification_token'] as String;
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
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    return _body(await http.Response.fromStream(streamed));
  }

  /// Signs the driver in and keeps the token. Throws a [DriverApiException]
  /// whose [DriverApiException.applicationStatus] is set when the account is
  /// real but not approved yet.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'device_name': 'Vendo Transport Driver mobile',
          }),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw DriverApiException(
        data['message']?.toString() ?? 'Could not sign in.',
        statusCode: response.statusCode,
        applicationStatus: data['status']?.toString(),
        reviewingHub: data['reviewing_hub']?.toString(),
        rejectionReason: data['rejection_reason']?.toString(),
      );
    }

    await _saveSession(data, email);
    return data;
  }

  /// Signs in with a Google ID token. The API verifies the token and answers
  /// with the same session as [login], so an approved driver lands in the app
  /// and a pending application gets the same "waiting for approval" error.
  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/google'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'credential': idToken,
            'device_name': 'Vendo Transport Driver mobile',
          }),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw DriverApiException(
        data['message']?.toString() ?? 'Could not sign in with Google.',
        statusCode: response.statusCode,
        applicationStatus: data['status']?.toString(),
        reviewingHub: data['reviewing_hub']?.toString(),
        rejectionReason: data['rejection_reason']?.toString(),
      );
    }

    await _saveSession(
      data,
      (data['driver'] as Map)['email']?.toString() ?? '',
    );
    return data;
  }

  /// Keeps the signed-in driver exactly as the API described them.
  Future<void> _saveSession(Map<String, dynamic> data, String email) async {
    await _storage.write(key: 'driver_token', value: data['token'] as String);
    await _storage.write(
      key: 'driver_name',
      value: (data['driver'] as Map)['name']?.toString(),
    );
    await _storage.write(
      key: 'driver_apply_label',
      value: (data['driver'] as Map)['apply_label']?.toString(),
    );
    await _storage.write(
      key: 'driver_reviewing_hub',
      value: (data['reviewing_hub'] as Map?)?['name']?.toString(),
    );
    await _storage.write(
      key: 'driver_station_hub',
      value: (data['station_hub'] as Map?)?['name']?.toString(),
    );
    await saveProfile(data);
    await saveApplicationEmail(email);
  }

  /// Returns the application, or null when there is no application for the
  /// email. Used by the sign-in screen before the first sign-in.
  Future<Map<String, dynamic>?> applicationStatus(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/application-status'),
          headers: _jsonHeaders,
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 404) return null;
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw DriverApiException(
        data['message']?.toString() ?? 'Could not load your application.',
        statusCode: response.statusCode,
      );
    }
    return (data['application'] as Map?) == null
        ? null
        : Map<String, dynamic>.from(data['application'] as Map);
  }

  /// The signed-in driver, as the web approved them. Throws a
  /// [DriverApiException] with [DriverApiException.isUnauthenticated] for an
  /// expired or revoked token.
  Future<Map<String, dynamic>> me() async {
    final data = await _authorizedGet(
      '/me',
      fallbackMessage: 'Could not load your driver account.',
    );
    await saveProfile(data);
    return data;
  }

  /// A signed-in GET. Every authenticated call goes through here so a revoked
  /// token is reported the same way across the app.
  Future<Map<String, dynamic>> _authorizedGet(
    String path, {
    String fallbackMessage = 'Could not load your trips.',
  }) async {
    final response = await http
        .get(Uri.parse('$baseUrl$path'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _authorizedBody(response, fallbackMessage: fallbackMessage);
  }

  /// A signed-in POST. Used for the trip actions, which answer with a readable
  /// message when the server refuses them.
  Future<Map<String, dynamic>> _authorizedPost(
    String path, {
    String fallbackMessage = 'Could not update this trip.',
  }) async {
    final response = await http
        .post(Uri.parse('$baseUrl$path'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _authorizedBody(response, fallbackMessage: fallbackMessage);
  }

  Future<Map<String, dynamic>> _authorizedBody(
    http.Response response, {
    required String fallbackMessage,
  }) async {
    final data = _decode(response);
    if (response.statusCode >= 400) {
      if (response.statusCode == 401) await clearSession();
      throw DriverApiException(
        data['message']?.toString() ?? fallbackMessage,
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  /// The trips the hub already assigned to the driver: in transit first, then
  /// scheduled. Throws a [DriverApiException] with
  /// [DriverApiException.isUnauthenticated] when the token is no longer
  /// accepted, so the app can ask for a fresh sign-in.
  Future<List<Map<String, dynamic>>> trips() async {
    final data = await _authorizedGet('/trips');
    final raw = data['trips'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((trip) => Map<String, dynamic>.from(trip))
        .toList(growable: false);
  }

  /// The accrued per-stop shipping shares the web ledger credits to this
  /// driver. Amounts are server-calculated; the app only displays them.
  Future<Map<String, dynamic>> earnings() async {
    return _authorizedGet(
      '/earnings',
      fallbackMessage: 'Could not load your earnings.',
    );
  }

  /// Notifications the web addressed to this driver's account: trip
  /// assignments, arrival records and the company's own updates.
  Future<Map<String, dynamic>> notifications() async {
    return _authorizedGet(
      '/notifications',
      fallbackMessage: 'Could not load your notifications.',
    );
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _authorizedPost(
      '/notifications/$notificationId/read',
      fallbackMessage: 'Could not mark this notification as read.',
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _authorizedPost(
      '/notifications/read-all',
      fallbackMessage: 'Could not mark your notifications as read.',
    );
  }

  /// The trips the driver already closed, newest first. Kept apart from
  /// [trips] because the board only carries scheduled and in-transit runs.
  Future<List<Map<String, dynamic>>> tripHistory() async {
    final data = await _authorizedGet(
      '/trips/history',
      fallbackMessage: 'Could not load your trip history.',
    );
    final raw = data['trips'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((trip) => Map<String, dynamic>.from(trip))
        .toList(growable: false);
  }

  /// Starts the trip. The server refuses with a 409 and a readable reason when
  /// a manifest parcel has not been scanned at the origin yet.
  Future<Map<String, dynamic>> departTrip(int tripId) async {
    final data = await _authorizedPost('/trips/$tripId/depart');
    return Map<String, dynamic>.from(data['trip'] as Map);
  }

  /// Records the driver's load scan for one parcel or for a whole container
  /// label. The answer carries the trip as the server now sees it, so the
  /// screens follow the real origin scan counts instead of guessing.
  Future<Map<String, dynamic>> scanParcels(
    int tripId,
    List<String> trackingNumbers,
    String scanKey,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/trips/$tripId/scan'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'tracking_numbers': trackingNumbers
                .map((tracking) => tracking.trim())
                .where((tracking) => tracking.isNotEmpty)
                .toList(),
            'scan_key': scanKey,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final data = await _authorizedBody(
      response,
      fallbackMessage: 'Could not record this scan.',
    );
    return {
      'trip': Map<String, dynamic>.from(data['trip'] as Map),
      'duplicate': data['duplicate'] == true,
      'message': data['message']?.toString() ?? '',
      'scanned': (data['recorded'] as List? ?? const []).length,
    };
  }

  /// Completes the trip. The server refuses with a 409 and a readable reason
  /// when a parcel has not been received at the destination yet.
  Future<Map<String, dynamic>> arriveTrip(int tripId) async {
    final data = await _authorizedPost('/trips/$tripId/arrive');
    return Map<String, dynamic>.from(data['trip'] as Map);
  }

  /// Keeps the signed-in driver on the device, so a restart can show the real
  /// profile while [me] refreshes it from the web.
  Future<void> saveProfile(Map<String, dynamic> data) async {
    final copy = Map<String, dynamic>.from(data)
      ..remove('token')
      ..remove('token_type')
      ..remove('expires_at');
    await _storage.write(key: 'driver_profile', value: jsonEncode(copy));
  }

  /// The last profile the web returned, or null before the first sign-in.
  Future<Map<String, dynamic>?> savedProfile() async {
    final raw = await _storage.read(key: 'driver_profile');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return null;
    }
  }

  Future<void> sendPasswordResetCode(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/password/otp/send'),
          headers: _jsonHeaders,
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 25));
    _body(response);
  }

  Future<String> verifyPasswordResetCode(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/password/otp/verify'),
          headers: _jsonHeaders,
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response)['reset_token'] as String;
  }

  Future<void> resetPassword(
    String email,
    String resetToken,
    String password,
    String confirmation,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/password/reset'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'email': email.trim(),
            'reset_token': resetToken,
            'password': password,
            'password_confirmation': confirmation,
          }),
        )
        .timeout(const Duration(seconds: 25));
    _body(response);
  }

  Future<void> logout() async {
    if (await hasToken()) {
      try {
        await http
            .post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders())
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // The local session is cleared even when the server is unreachable.
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'driver_token');
    await _storage.delete(key: 'driver_name');
    await _storage.delete(key: 'driver_apply_label');
    await _storage.delete(key: 'driver_reviewing_hub');
    await _storage.delete(key: 'driver_station_hub');
    await _storage.delete(key: 'driver_profile');
  }

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Headers for a signed-in call. Throws a 401 [DriverApiException] before
  /// the request when there is no token at all.
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'driver_token');
    if (token == null) {
      throw const DriverApiException('Sign in to continue.', statusCode: 401);
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _body(http.Response response) {
    final data = _decode(response);
    if (response.statusCode >= 400) {
      final errors = data['errors'];
      final detail = errors is Map && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : (data['message']?.toString() ??
                'Request failed. Please try again.');
      throw DriverApiException(detail, statusCode: response.statusCode);
    }
    return data;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on FormatException {
      throw DriverApiException(
        'HTTP ${response.statusCode} from ${response.request?.url ?? baseUrl}. Check that this Vendo API version is running.',
        statusCode: response.statusCode,
      );
    }
  }
}
