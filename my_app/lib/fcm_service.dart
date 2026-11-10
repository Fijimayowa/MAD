import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Centralizes all FCM behavior. The UI listens to this object and rebuilds.
class FCMService extends ChangeNotifier {
  /// Allowlist: only these values may select a bundled image.
  static const Set<String> supportedAssets = {'default', 'promo'};

  // Visible state
  String title = 'Waiting for a message';
  String asset = 'default';
  String? diagnostic;

  // Evidence state (shows a fresh event even when the payload repeats)
  String lastHandler = 'none';
  int receiptCount = 0;
  String? messageId;

  // Setup info for your reflection (do NOT submit the token itself)
  String permissionStatus = 'unknown';
  String? token;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  bool _initialized = false;
  bool _disposed = false;

  Future<void> initialize() async {
    if (_initialized) return; // prevents duplicate listeners
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission();
    permissionStatus = settings.authorizationStatus.name;

    token = await messaging.getToken();
    debugPrint('FCM token (redact before sharing): $token');

    // 1) Foreground receipt
    _onMessageSub = FirebaseMessaging.onMessage
        .listen((m) => _handle(m, 'onMessage'));

    // 2) Notification tapped while app was in the background
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _handle(m, 'onMessageOpenedApp'));

    // 3) Notification tapped while app was terminated (cold start).
    //    Returns null on an ordinary launcher start.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handle(initial, 'getInitialMessage');
    }

    _safeNotify();
  }

  void _handle(RemoteMessage message, String handler) {
    receiptCount++;
    lastHandler = handler;
    messageId = message.messageId;

    final data = message.data;
    final action = data['action'];
    final requestedAsset = data['asset'];

    if (action != 'update_ui') {
      diagnostic = 'Ignored: action is "$action", expected "update_ui".';
    } else if (requestedAsset == null) {
      diagnostic = 'Rejected: missing "asset" key.';
    } else if (!supportedAssets.contains(requestedAsset)) {
      diagnostic = 'Rejected: unsupported asset "$requestedAsset".';
    } else {
      // Valid: update visible content.
      asset = requestedAsset;
      title = message.notification?.title ?? title;
      diagnostic = null;
    }
    // On rejection, title and asset are left unchanged (T4 preservation).

    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    super.dispose();
  }
}
