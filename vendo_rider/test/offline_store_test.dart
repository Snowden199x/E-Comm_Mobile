import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/core/offline/offline_store.dart';

/// Stands in for the Vendo API so the outbox can be tested without a server.
class _FakeClient extends http.BaseClient {
  _FakeClient({this.statusCode = 200, this.body = '{"duplicate": false}'});

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
    RiderApi.instance.debugToken = 'test-token';
  });

  tearDown(() {
    OfflineStore.instance = OfflineStore.withStorage(
      const SecureOfflineStorage(),
    );
    RiderApi.instance.debugToken = null;
    RiderApi.instance.useClient(http.Client());
  });

  test('saved assignments keep their payload and saved time', () async {
    final payload = <String, dynamic>{
      'assignments': [
        {'order_id': 12, 'tracking_number': 'VND-12'},
      ],
      'summary': {'loaded': 1},
    };

    await OfflineStore.instance.cacheAssignments(payload);
    final cached = await OfflineStore.instance.cachedAssignments();

    expect(cached, isNotNull);
    expect(cached!.payload, payload);
    expect(
      DateTime.now().difference(cached.cachedAt).inMinutes,
      lessThan(1),
    );
  });

  test('a scan queued offline uploads once and clears on sync', () async {
    final client = _FakeClient();
    RiderApi.instance.useClient(client);

    await RiderApi.instance.queueScanOffline('VND-1', 'pickup', 'key-1');
    // The same scan key never queues twice, so a retried scan cannot
    // double-count on the server.
    await RiderApi.instance.queueScanOffline('VND-1', 'pickup', 'key-1');
    expect(await RiderApi.instance.pendingOfflineActions(), 1);

    final report = await RiderApi.instance.syncOfflineActions();

    expect(report.synced, 1);
    expect(await RiderApi.instance.pendingOfflineActions(), 0);
    expect(client.requests, hasLength(1));
    final request = client.requests.single;
    expect(request.url.path, endsWith('/scans'));
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['tracking_number'], 'VND-1');
    expect(body['scan_type'], 'pickup');
    expect(body['scan_key'], 'key-1');
  });

  test('queued work is kept when the upload cannot reach Vendo', () async {
    RiderApi.instance.useClient(
      _FakeClient(statusCode: 503, body: '{"message": "Service down"}'),
    );

    await RiderApi.instance.queueScanOffline('VND-2', 'delivered', 'key-2');
    final report = await RiderApi.instance.syncOfflineActions();

    expect(report.synced, 0);
    expect(await RiderApi.instance.pendingOfflineActions(), 1);
  });

  test('corrupted saved data does not break the app', () async {
    final storage = MemoryOfflineStorage();
    OfflineStore.instance = OfflineStore.withStorage(storage);
    await storage.write(OfflineStore.assignmentsKey, 'not json');
    await storage.write('offline:outbox', '{"nope": true}');

    expect(await OfflineStore.instance.cachedAssignments(), isNull);
    expect(await OfflineStore.instance.pendingActions(), isEmpty);
    expect(await OfflineStore.instance.pendingCount(), 0);
  });
}
