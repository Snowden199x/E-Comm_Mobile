import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

/// Uploads the Rider's offline outbox the moment the phone gets a connection
/// again, so the station sees a scan without the Rider opening a tab first.
///
/// It watches the connectivity stream, retries on a timer while work is still
/// queued (a connection type does not guarantee the API is reachable), and
/// publishes [completedSyncs] so open screens can refresh themselves.
class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  /// Bumped whenever at least one queued action uploaded successfully.
  final ValueNotifier<int> completedSyncs = ValueNotifier<int>(0);

  /// Number of actions still waiting on the device.
  final ValueNotifier<int> pendingActions = ValueNotifier<int>(0);

  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _retryTimer;
  bool _started = false;
  bool _syncing = false;

  Future<void> start() async {
    await refreshPending();
    if (_started) {
      await syncNow();
      return;
    }
    _started = true;

    try {
      _connectivity ??= Connectivity().onConnectivityChanged.listen((results) {
        final online = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (online) syncNow();
      });
    } catch (_) {
      // Without connectivity events the timer below still retries the queue.
    }

    _retryTimer ??= Timer.periodic(const Duration(seconds: 45), (_) {
      if (pendingActions.value > 0) syncNow();
    });

    await syncNow();
  }

  void stop() {
    _connectivity?.cancel();
    _connectivity = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _started = false;
  }

  Future<void> refreshPending() async {
    pendingActions.value = await RiderApi.instance.pendingOfflineActions();
  }

  /// Sends everything queued. Returns null when the queue is empty or still
  /// offline, so callers do not report a sync that did nothing.
  Future<OfflineSyncReport?> syncNow() async {
    if (_syncing) return null;
    _syncing = true;
    try {
      final pending = await RiderApi.instance.pendingOfflineActions();
      if (pending == 0) {
        pendingActions.value = 0;
        return null;
      }
      final report = await RiderApi.instance.syncOfflineActions();
      await refreshPending();
      if (report.synced > 0) completedSyncs.value++;
      return report;
    } catch (_) {
      return null;
    } finally {
      _syncing = false;
    }
  }

  @visibleForTesting
  void reset() {
    stop();
    completedSyncs.value = 0;
    pendingActions.value = 0;
  }
}
