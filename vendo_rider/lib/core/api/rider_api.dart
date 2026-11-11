import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:vendo_rider/core/offline/offline_store.dart';

class RiderApiException implements Exception {
  const RiderApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// What happened when the offline outbox was flushed back to Vendo.
class OfflineSyncReport {
  const OfflineSyncReport({
    required this.synced,
    required this.failed,
    required this.messages,
  });

  final int synced;
  final int failed;
  final List<String> messages;

  bool get hasFailures => failed > 0;
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

  /// Shared HTTP client. Tests swap it with [useClient].
  http.Client _client = http.Client();

  /// Test hook: supplies the bearer token without the platform keychain.
  @visibleForTesting
  String? debugToken;

  @visibleForTesting
  void useClient(http.Client client) => _client = client;

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'rider_token')) != null;
  Future<String?> riderName() => _storage.read(key: 'rider_name');
  Future<String?> centerName() => _storage.read(key: 'center_name');
  Future<String?> riderVehicleType() =>
      _storage.read(key: 'rider_vehicle_type');

  /// Keeps the cached header name in step after a profile edit.
  Future<void> saveRiderName(String name) =>
      _storage.write(key: 'rider_name', value: name);

  /// Bumped after a profile edit so open screens can refresh the header.
  final ValueNotifier<int> profileRevision = ValueNotifier<int>(0);

  void notifyProfileChanged() => profileRevision.value++;

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

  /// Logistics companies whose Station Hub network covers this municipality.
  Future<Map<String, dynamic>> logisticsCompanies({
    required String provinceCode,
    required String cityCode,
  }) async {
    final uri = Uri.parse('$baseUrl/logistics-companies').replace(
      queryParameters: {
        'province_code': provinceCode,
        'city_code': cityCode,
      },
    );
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
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
    final data = _body(response);
    // Keep the newest work on the device so the next launch works offline.
    await OfflineStore.instance.cacheAssignments(data);
    return data;
  }

  /// Parcels this Rider completed on [date] (`Y-m-d`); today when omitted.
  Future<Map<String, dynamic>> deliveryHistory({String? date}) async {
    final uri = Uri.parse('$baseUrl/deliveries/history').replace(
      queryParameters: date != null && date.isNotEmpty ? {'date': date} : null,
    );
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  /// The last assigned-parcel list this device saw, when the API cannot be
  /// reached.
  Future<CachedPayload?> cachedWork() =>
      OfflineStore.instance.cachedAssignments();

  /// The last earnings payload saved on this device.
  Future<CachedPayload?> cachedEarnings({bool transportDriver = false}) =>
      OfflineStore.instance.readJson(
        transportDriver
            ? OfflineStore.transportDriverEarningsKey
            : OfflineStore.earningsKey,
      );

  /// The last notifications list saved on this device.
  Future<CachedPayload?> cachedNotifications() =>
      OfflineStore.instance.readJson(OfflineStore.notificationsKey);

  Future<int> pendingOfflineActions() => OfflineStore.instance.pendingCount();

  Future<void> queueScanOffline(
    String trackingNumber,
    String scanType,
    String scanKey, {
    int? orderId,
  }) => OfflineStore.instance.enqueue(
    kind: 'scan',
    fields: {
      'tracking_number': trackingNumber,
      'scan_type': scanType,
      'scan_key': scanKey,
      // Return legs post to their own endpoint, which needs the order id.
      if (orderId != null) 'order_id': orderId,
    },
  );

  Future<void> queueFacilityScanOffline(
    String trackingNumber,
    int facilityId,
    String scanKey,
  ) => OfflineStore.instance.enqueue(
    kind: 'facility_scan',
    fields: {
      'tracking_number': trackingNumber,
      'facility_id': facilityId,
      'scan_key': scanKey,
    },
  );

  Future<void> queueDeliveryProofOffline({
    required String trackingNumber,
    required String scanKey,
    required String recipientName,
    required String photoPath,
    double? cashCollected,
  }) => OfflineStore.instance.enqueue(
    kind: 'delivery_proof',
    fields: {
      'tracking_number': trackingNumber,
      'scan_key': scanKey,
      'recipient_name': recipientName,
      'photo_path': photoPath,
      if (cashCollected != null)
        'cash_collected': cashCollected.toStringAsFixed(2),
    },
  );

  /// Uploads everything the Rider saved while offline.
  ///
  /// Stops early when the connection is still down, keeps the queue for the
  /// next attempt, and drops entries the server has already recorded or can no
  /// longer accept so one stale parcel never blocks the rest.
  Future<OfflineSyncReport> syncOfflineActions() async {
    final actions = await OfflineStore.instance.pendingActions();
    var synced = 0;
    var failed = 0;
    final messages = <String>[];

    for (final action in actions) {
      final id = '${action['id'] ?? ''}';
      final tracking = '${action['tracking_number'] ?? ''}';
      final kind = '${action['kind'] ?? ''}';
      final scanKey = '${action['scan_key'] ?? ''}';

      try {
        if (tracking.isEmpty || scanKey.isEmpty) {
          await OfflineStore.instance.removeAction(id);
          continue;
        }
        if (kind == 'scan') {
          final scanType = '${action['scan_type'] ?? ''}';
          final returnOrderId = int.tryParse('${action['order_id'] ?? ''}');
          if (scanType == 'return_pickup' || scanType == 'returned_to_seller') {
            if (returnOrderId == null || returnOrderId == 0) {
              await OfflineStore.instance.removeAction(id);
              failed++;
              continue;
            }
            if (scanType == 'return_pickup') {
              await returnPickup(
                orderId: returnOrderId,
                trackingNumber: tracking,
                scanKey: scanKey,
              );
            } else {
              await returnHandover(
                orderId: returnOrderId,
                trackingNumber: tracking,
                scanKey: scanKey,
              );
            }
          } else {
            await scan(tracking, scanType, scanKey);
          }
        } else if (kind == 'facility_scan') {
          final facilityId = int.tryParse('${action['facility_id']}') ?? 0;
          if (facilityId == 0) {
            await OfflineStore.instance.removeAction(id);
            continue;
          }
          await scanFacility(tracking, facilityId, scanKey);
        } else if (kind == 'delivery_proof') {
          final photoPath = '${action['photo_path'] ?? ''}';
          if (photoPath.isEmpty || !File(photoPath).existsSync()) {
            await OfflineStore.instance.removeAction(id);
            failed++;
            messages.add(
              '$tracking: the saved delivery photo is no longer on this device.',
            );
            continue;
          }
          await submitDeliveryProof(
            trackingNumber: tracking,
            scanKey: scanKey,
            recipientName: '${action['recipient_name'] ?? ''}',
            photoPath: photoPath,
            cashCollected: double.tryParse(
              '${action['cash_collected'] ?? ''}',
            ),
          );
        } else {
          await OfflineStore.instance.removeAction(id);
          continue;
        }
        await OfflineStore.instance.removeAction(id);
        synced++;
      } on RiderApiException catch (error) {
        final code = error.statusCode ?? 0;
        if (code == 401 || code == 403) {
          messages.add(error.message);
          break;
        }
        if (code >= 400 && code < 500) {
          // The server rejected this one (already recorded, or the parcel moved
          // on). Retrying forever would block the queue.
          await OfflineStore.instance.removeAction(id);
          failed++;
          messages.add('$tracking: ${error.message}');
          continue;
        }
        failed++;
        messages.add('$tracking: ${error.message}');
      } catch (_) {
        // Still offline: keep this and everything after it queued.
        failed++;
        break;
      }
    }

    return OfflineSyncReport(synced: synced, failed: failed, messages: messages);
  }

  Future<Map<String, dynamic>> riderNotifications({int? since}) async {
    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: since != null && since > 0 ? {'since': '$since'} : null,
    );
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    final data = _body(response);
    // Only the full list is cached; a `since` page would cache a partial list.
    if (since == null || since <= 0) {
      await OfflineStore.instance.cacheJson(
        OfflineStore.notificationsKey,
        data,
      );
    }
    return data;
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

  /// COD cash the rider collected and still holds, plus recent collections.
  /// The signed-in Rider's own profile: personal details, home address,
  /// vehicle, Station Hub, and which private documents are on file.
  Future<Map<String, dynamic>> riderProfile() async {
    final response = await http
        .get(Uri.parse('$baseUrl/profile'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(_body(response)['rider'] as Map);
  }

  /// Updates the signed-in Rider's name and birthday. Contact details,
  /// vehicle, documents, and the Station Hub assignment stay hub-managed.
  Future<Map<String, dynamic>> updateRiderProfile({
    required String firstName,
    required String middleName,
    required String lastName,
    required String birthday,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/profile'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'first_name': firstName,
            'middle_name': middleName,
            'last_name': lastName,
            'birthday': birthday,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(_body(response)['rider'] as Map);
  }

  /// Replaces the signed-in Rider's profile picture. The image goes to the web
  /// app's public profile storage, not the private verification documents.
  Future<Map<String, dynamic>> uploadProfilePicture(String photoPath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/photo'),
    );
    final headers = await _authHeaders();
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    return Map<String, dynamic>.from(
      _body(await http.Response.fromStream(streamed))['rider'] as Map,
    );
  }

  /// Changes the signed-in Rider's password. The API checks the current
  /// password and keeps this device signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/profile/password'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'current_password': currentPassword,
            'password': password,
            'password_confirmation': confirmation,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _body(response);
  }

  Future<Map<String, dynamic>> riderCash() async {
    final response = await http
        .get(Uri.parse('$baseUrl/cash'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return _body(response);
  }

  Future<Map<String, dynamic>> earnings({bool transportDriver = false}) async {
    final base = transportDriver ? transportDriverBaseUrl : baseUrl;
    final headers = transportDriver
        ? await _transportDriverHeaders()
        : await _authHeaders();
    final response = await http
        .get(Uri.parse('$base/earnings'), headers: headers)
        .timeout(const Duration(seconds: 20));
    final data = _body(response);
    await OfflineStore.instance.cacheJson(
      transportDriver
          ? OfflineStore.transportDriverEarningsKey
          : OfflineStore.earningsKey,
      data,
    );
    return data;
  }

  Future<Map<String, dynamic>> scan(
    String trackingNumber,
    String scanType,
    String scanKey,
  ) async {
    // Uses [_client] so the offline outbox can be tested without a server.
    final response = await _client
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

  /// Collects the returned parcel from the Buyer (approved return only).
  Future<Map<String, dynamic>> returnPickup({
    required int orderId,
    required String trackingNumber,
    required String scanKey,
  }) => _returnLeg('return-pickup', orderId, trackingNumber, scanKey);

  /// Hands the collected return back to the Seller.
  Future<Map<String, dynamic>> returnHandover({
    required int orderId,
    required String trackingNumber,
    required String scanKey,
  }) => _returnLeg('return-handover', orderId, trackingNumber, scanKey);

  Future<Map<String, dynamic>> _returnLeg(
    String action,
    int orderId,
    String trackingNumber,
    String scanKey,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/deliveries/$orderId/$action'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'tracking_number': trackingNumber,
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
    double? cashCollected,
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
      // COD cash handed over by the Buyer. The server requires it for orders
      // whose cash is still uncollected, and rejects any other amount.
      if (cashCollected != null)
        'cash_collected': cashCollected.toStringAsFixed(2),
    });
    request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    return _body(await http.Response.fromStream(streamed));
  }

  /// Books the next delivery attempt after the daily window closed.
  Future<Map<String, dynamic>> rescheduleDelivery(int orderId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/deliveries/$orderId/reschedule'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return _body(response);
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

  /// Registers this phone's FCM token so Rider notifications also arrive as push.
  Future<Map<String, dynamic>> registerPushToken(
    String token,
    String platform,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/push-tokens'),
          headers: await _authHeaders(),
          body: jsonEncode({'token': token, 'platform': platform}),
        )
        .timeout(const Duration(seconds: 20));
    final data = _body(response);
    await _storage.write(key: 'push_token', value: token);
    return data;
  }

  /// Drops this phone's token (logout or permission revoked). Best effort.
  Future<void> removePushToken([String? token]) async {
    final value = token ?? await _storage.read(key: 'push_token');
    if (value == null || value.isEmpty) return;
    try {
      await http
          .delete(
            Uri.parse('$baseUrl/push-tokens'),
            headers: await _authHeaders(),
            body: jsonEncode({'token': value}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Signing out must succeed even when the API is unreachable.
    }
    await _storage.delete(key: 'push_token');
  }

  Future<void> logout() async {
    await removePushToken();
    final response = await http
        .post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    _body(response);
    await _storage.deleteAll();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = debugToken ?? await _storage.read(key: 'rider_token');
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
