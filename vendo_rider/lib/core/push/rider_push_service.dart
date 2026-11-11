import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/rider_api.dart';
import '../notifications/rider_notification_center.dart';

/// Handles a push that arrives while the app is terminated or in the background.
/// The notification payload is drawn by the system tray; the app refreshes from
/// the API when it opens, so there is nothing else to write here.
@pragma('vm:entry-point')
Future<void> riderPushBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging for Rider notifications.
///
/// The app already polls `GET /api/v1/rider/notifications` every 25 seconds, so
/// push is an accelerator, not a dependency. When the build has no Firebase
/// options (or the owner has not configured the server key) startup is skipped
/// quietly and polling stays the delivery path.
class RiderPushService {
  RiderPushService._();

  static final RiderPushService instance = RiderPushService._();

  bool _started = false;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;

  /// True once Firebase initialized and the token was registered.
  bool available = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await RiderApi.instance.registerPushToken(token, _platform);
        available = true;
      }

      _tokenRefresh = messaging.onTokenRefresh.listen((fresh) async {
        try {
          await RiderApi.instance.registerPushToken(fresh, _platform);
          available = true;
        } catch (_) {
          // The next sign-in retries with a fresh token.
        }
      });

      // Foreground pushes do not draw a tray notification; refresh the feed so
      // the existing in-app banner and badge update immediately.
      _foreground = FirebaseMessaging.onMessage.listen((_) {
        unawaited(RiderNotificationCenter.instance.poll());
      });

      _opened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
        unawaited(RiderNotificationCenter.instance.poll());
      });
    } catch (_) {
      available = false;
    }
  }

  /// Called on sign-out so the next sign-in registers a fresh token.
  void reset() {
    _tokenRefresh?.cancel();
    _foreground?.cancel();
    _opened?.cancel();
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;
    _started = false;
    available = false;
  }

  /// Build-time Firebase options; null lets Firebase use the platform config
  /// files (google-services.json / GoogleService-Info.plist) when present.
  FirebaseOptions? get _options {
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if (projectId.isEmpty || appId.isEmpty || apiKey.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    );
  }

  String get _platform => Platform.isIOS ? 'ios' : 'android';
}
