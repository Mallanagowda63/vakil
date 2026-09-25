import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'call_service.dart';
import 'consultation_service.dart';

/// Runs in its own isolate when a push arrives while the app is in the
/// background or closed (the phone may be locked): rings incoming calls.
@pragma('vm:entry-point')
Future<void> _backgroundPush(RemoteMessage message) => handleCallPushInBackground(message.data);

/// Notification channels, the Android 13+ permission prompt and Firebase
/// Cloud Messaging. Pushes arrive when the app is in the background or
/// closed; a tap calls [onOpen] with the push data (type + requestId).
class PushService {
  PushService._();
  static final instance = PushService._();

  static const requestsChannel = AndroidNotificationChannel('chat_requests', 'Chat requests',
      description: 'New consultation requests', importance: Importance.max, sound: RawResourceAndroidNotificationSound('request_ring'), enableVibration: true);
  static const messagesChannel = AndroidNotificationChannel('chat_messages', 'Messages',
      description: 'New chat messages', importance: Importance.high, sound: RawResourceAndroidNotificationSound('message'), enableVibration: true);

  final _local = FlutterLocalNotificationsPlugin();
  bool firebaseReady = false;
  StreamSubscription<String>? _tokenRefresh;

  Future<void> init({required void Function(Map<String, dynamic> data) onOpen}) async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) onOpen(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        },
      );
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(requestsChannel);
      await android?.createNotificationChannel(messagesChannel);
      await android?.requestNotificationsPermission();
    } catch (error) {
      debugPrint('Notification setup failed: $error');
    }

    // Needs android/app/google-services.json; without it the app keeps working over sockets.
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (error) {
      debugPrint('Push notifications disabled (Firebase not configured): $error');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(_backgroundPush);
    FirebaseMessaging.onMessage.listen((message) => CallService.instance.onPush(message.data));
    FirebaseMessaging.onMessageOpenedApp.listen((message) => onOpen(message.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) onOpen(initial.data);
  }

  /// Sends this phone's FCM token to the server so it can reach the lawyer when offline.
  Future<void> registerDevice(String authToken) async {
    if (!firebaseReady) return;
    try {
      final service = PartnerConsultationService();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) await service.registerDevice(authToken, fcmToken);
      await _tokenRefresh?.cancel();
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((t) => service.registerDevice(authToken, t).catchError((_) {}));
    } catch (error) {
      debugPrint('FCM registration failed: $error');
    }
  }
}
