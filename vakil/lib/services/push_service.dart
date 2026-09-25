import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'call_service.dart';

/// Runs in its own isolate when a push arrives while the app is in the
/// background or closed (the phone may be locked).
@pragma('vm:entry-point')
Future<void> _backgroundPush(RemoteMessage message) => handleCallPushInBackground(message.data);

/// Firebase Cloud Messaging. The User App uses it to ring for incoming voice
/// calls when the app is not open; everything else arrives over the socket.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool firebaseReady = false;
  StreamSubscription<String>? _tokenRefresh;
  Future<void>? _starting;

  Future<void> init() => _starting ??= _start();

  Future<void> _start() async {
    // Needs android/app/google-services.json; without it calls only ring while the app is open.
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (error) {
      debugPrint('Push notifications disabled (Firebase not configured): $error');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(_backgroundPush);
    FirebaseMessaging.onMessage.listen((message) => CallService.instance.onPush(message.data));
  }

  /// Sends this phone's FCM token to the server so calls can reach it when the app is closed.
  Future<void> registerDevice(String authToken) async {
    await init();
    if (!firebaseReady) return;
    try {
      final api = ApiClient();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) await api.post('/api/devices', {'token': fcmToken}, token: authToken);
      await _tokenRefresh?.cancel();
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((t) => api.post('/api/devices', {'token': t}, token: authToken).catchError((_) => <String, dynamic>{}));
    } catch (error) {
      debugPrint('FCM registration failed: $error');
    }
  }
}
