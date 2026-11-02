import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The last payload the API returned for a screen, kept on the device so the
/// Buyer app still opens without a connection.
class CachedPayload {
  const CachedPayload({required this.payload, required this.cachedAt});

  final Map<String, dynamic> payload;
  final DateTime cachedAt;
}

/// Tiny key-value backend. Splitting this out keeps the offline store testable
/// without the platform keychain.
abstract class OfflineKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Production storage: the same encrypted store as the Buyer login token.
class SecureOfflineStorage implements OfflineKeyValueStore {
  const SecureOfflineStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }
}

/// In-memory storage used by tests.
class MemoryOfflineStorage implements OfflineKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

/// Offline support for the Buyer app.
///
/// Two things are kept on the device:
///  • the last successful payload for Orders, one order, and Notifications, so
///    tracking survives a bad signal instead of showing an error screen;
///  • an outbox for small, safe account writes taken without a connection
///    (marking notifications read). Placing an order is never queued: stock,
///    COD amount, vouchers, and the delivery route must be confirmed live.
///
/// Everything lives in the same secure storage as the login token, so logging
/// out on a shared phone removes the cached data and the pending uploads.
class OfflineStore {
  OfflineStore.withStorage(this._storage);

  static OfflineStore instance = OfflineStore.withStorage(
    const SecureOfflineStorage(),
  );

  static const String _outboxKey = 'offline:outbox';

  OfflineKeyValueStore _storage;

  @visibleForTesting
  void debugUseStorage(OfflineKeyValueStore storage) => _storage = storage;

  /// Keeps the latest payload for a screen together with the time it arrived.
  Future<void> cacheJson(String key, Map<String, dynamic> payload) async {
    try {
      await _storage.write(
        key,
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'payload': payload,
        }),
      );
    } catch (_) {
      // Caching is best effort; a full disk must not break the live response.
    }
  }

  Future<CachedPayload?> readJson(String key) async {
    try {
      final raw = await _storage.read(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final payload = decoded['payload'];
      if (payload is! Map) return null;
      return CachedPayload(
        payload: Map<String, dynamic>.from(payload),
        cachedAt: DateTime.tryParse('${decoded['saved_at']}') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Queues one upload. [dedupeKey] keeps the same action from piling up when a
  /// Buyer taps a button twice offline.
  Future<void> enqueue({
    required String kind,
    Map<String, dynamic> fields = const {},
    String dedupeKey = '',
  }) async {
    final id = '$kind|$dedupeKey';
    final outbox = await pendingActions();
    if (outbox.any((action) => action['id'] == id)) return;
    outbox.add({
      'id': id,
      'kind': kind,
      'queued_at': DateTime.now().toIso8601String(),
      ...fields,
    });
    await _writeOutbox(outbox);
  }

  Future<List<Map<String, dynamic>>> pendingActions() async {
    try {
      final raw = await _storage.read(_outboxKey);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((action) => Map<String, dynamic>.from(action))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> pendingCount() async => (await pendingActions()).length;

  Future<void> removeAction(String id) async {
    if (id.isEmpty) return;
    final outbox = await pendingActions();
    outbox.removeWhere((action) => action['id'] == id);
    await _writeOutbox(outbox);
  }

  Future<void> _writeOutbox(List<Map<String, dynamic>> actions) async {
    try {
      await _storage.write(_outboxKey, jsonEncode(actions));
    } catch (_) {
      // Keeping the action locally is more important than failing the tap.
    }
  }
}
