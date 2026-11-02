import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/core/offline/offline_store.dart';

/// Stands in for the Vendo API so the outbox can be tested without a server.
class _FakeClient extends http.BaseClient {
  _FakeClient({this.statusCode = 200, this.body = '{"message": "ok"}'});

  final int statusCode;
  final String body;
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  setUp(() {
    OfflineStore.instance = OfflineStore.withStorage(MemoryOfflineStorage());
    BuyerApi.instance.debugToken = 'test-token';
  });

  tearDown(() {
    OfflineStore.instance = OfflineStore.withStorage(
      const SecureOfflineStorage(),
    );
    BuyerApi.instance.debugToken = null;
    BuyerApi.instance.useClient(http.Client());
  });

  test('saved payloads keep their data and saved time', () async {
    final payload = <String, dynamic>{
      'data': [
        {'id': 1, 'title': 'Order VN-000012 confirmed'},
      ],
    };

    await OfflineStore.instance.cacheJson('offline:notifications', payload);
    final cached = await OfflineStore.instance.readJson(
      'offline:notifications',
    );

    expect(cached, isNotNull);
    expect(cached!.payload, payload);
    expect(DateTime.now().difference(cached.cachedAt).inMinutes, lessThan(1));
  });

  test('a queued mark-all-read uploads once and clears on sync', () async {
    final client = _FakeClient();
    BuyerApi.instance.useClient(client);

    await BuyerApi.instance.queueMarkAllNotificationsReadOffline();
    // Tapping twice offline must not queue two uploads.
    await BuyerApi.instance.queueMarkAllNotificationsReadOffline();
    expect(await BuyerApi.instance.pendingOfflineActions(), 1);

    final report = await BuyerApi.instance.syncOfflineActions();

    expect(report.synced, 1);
    expect(await BuyerApi.instance.pendingOfflineActions(), 0);
    expect(client.requests, hasLength(1));
    expect(client.requests.single.url.path, endsWith('/notifications/read-all'));
    expect(client.requests.single.method, 'POST');
  });

  test('queued work is kept when the upload cannot reach Vendo', () async {
    BuyerApi.instance.useClient(
      _FakeClient(statusCode: 503, body: '{"message": "Service down"}'),
    );

    await BuyerApi.instance.queueMarkAllNotificationsReadOffline();
    final report = await BuyerApi.instance.syncOfflineActions();

    expect(report.synced, 0);
    expect(await BuyerApi.instance.pendingOfflineActions(), 1);
  });

  test('corrupted saved data does not break the app', () async {
    final storage = MemoryOfflineStorage();
    OfflineStore.instance = OfflineStore.withStorage(storage);
    await storage.write('offline:orders:all', 'not json');
    await storage.write('offline:outbox', '{"nope": true}');

    expect(await OfflineStore.instance.readJson('offline:orders:all'), isNull);
    expect(await OfflineStore.instance.pendingActions(), isEmpty);
    expect(await BuyerApi.instance.pendingOfflineActions(), 0);
  });
}
