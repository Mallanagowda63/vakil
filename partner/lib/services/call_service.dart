import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../config/api_config.dart';
import '../screens/call_screen.dart';
import 'app_keys.dart';
import 'partner_auth_service.dart';
import 'realtime_service.dart';

// This app's side of a call: its role on the server, where the session token
// is saved (read by the background handlers) and the live token.
const _myRole = 'lawyer';
const _tokenKey = 'partner_auth_token';
String? _sessionToken() => PartnerAuthService.instance.token;

/// Call diagnostics: `adb logcat | findstr "[CALL]"` shows every step of a call.
void _log(String message) => debugPrint('[CALL] $_myRole: $message');

/// Voice calls (audio only). The server owns the call's status; audio goes
/// through ZEGOCLOUD with a short-lived token from the server. Incoming calls
/// always ring on the phone's native full-screen call UI
/// (flutter_callkit_incoming): from the socket while the app is open, from an
/// FCM data push while it is in the background, closed or the phone is locked.
class CallService {
  CallService._();
  static final instance = CallService._();

  static const _window = MethodChannel('vakil/call_window');

  /// The call on screen, if any. Only one call at a time.
  final current = ValueNotifier<CallSession?>(null);
  StreamSubscription<SocketEvent>? _socketEvents;
  StreamSubscription<CallEvent?>? _callkitEvents;
  Route<void>? _route;
  bool _engineReady = false;
  bool _devicePrepared = false;
  // Calls accepted on the call UI before the app had a session (opened from closed).
  final _pendingAccepts = <CallKitParams>[];

  void init() {
    _socketEvents ??= RealtimeService.instance.events.stream.listen(_onSocket);
    _callkitEvents ??= FlutterCallkitIncoming.onEvent.listen(_onCallkit, onError: (Object e) => debugPrint('Call UI event error: $e'));
  }

  // ---------------------------------------------------------------- outgoing

  /// Rings the other side of an ongoing chat. Returns an error to show, or null.
  Future<String?> startCall({required String requestId, required String otherName, String? otherPhotoUrl}) async {
    if (current.value != null) return 'You are already on a call';
    if (!await _micAllowed()) return 'Allow microphone access to make voice calls';
    final Map<String, dynamic> res;
    try {
      res = await _post('/api/consultations/$requestId/call/start');
    } on CallFailure catch (e) {
      return e.message;
    }
    final call = Map<String, dynamic>.from(res['call'] as Map);
    _log('start callId=${call['id']} requestId=$requestId');
    final session = CallSession(callId: call['id'].toString(), requestId: requestId, otherName: otherName, otherPhotoUrl: otherPhotoUrl, outgoing: true, phase: CallPhase.calling)
      ..setTimeLeft(call['remainingSeconds']);
    _open(session);
    await _join(session, Map<String, dynamic>.from(res['zego'] as Map));
    return null;
  }

  // ---------------------------------------------------------------- incoming

  /// Push data (FCM) while the app is in the foreground.
  Future<void> onPush(Map<String, dynamic> data) async {
    if (data['type'] == 'incoming_call') {
      await _ring(callId: data['callId'].toString(), requestId: data['requestId'].toString(), callerName: data['callerName']?.toString() ?? 'Vakil', photoUrl: data['callerPhotoUrl']?.toString());
    } else if (data['type'] == 'call_ended') {
      await dismissIncomingCall(data['callId'].toString(), missed: data['status'] == 'missed');
    }
  }

  Future<void> _ring({required String callId, required String requestId, required String callerName, String? photoUrl}) async {
    if (current.value?.callId == callId) return;
    // Busy on another call: decline this one straight away.
    if (current.value != null) { _post('/api/calls/$callId/reject').catchError((_) => <String, dynamic>{}); return; }
    if (await showIncomingCall(callId: callId, requestId: requestId, callerName: callerName, photoUrl: photoUrl)) {
      _post('/api/calls/$callId/ringing').catchError((_) => <String, dynamic>{});
    }
  }

  Future<void> _answer(CallKitParams params) async {
    // Accept can arrive twice (the call UI event, and the resume check when the
    // app returns to the foreground): claim the call before any await.
    if (current.value != null) { _log('accept ignored callId=${params.id}: already on call ${current.value!.callId}'); return; }
    _log('accept callId=${params.id}');
    final session = CallSession(callId: params.id, requestId: params.extra?['requestId']?.toString() ?? '', otherName: params.nameCaller ?? 'Vakil', otherPhotoUrl: params.avatar, outgoing: false, phase: CallPhase.connecting);
    _open(session);
    await _showOverLockScreen(true);
    if (!await _micAllowed()) {
      _log('microphone permission denied');
      _post('/api/calls/${session.callId}/reject').catchError((_) => <String, dynamic>{});
      return _finish(session, 'Microphone access is needed for calls. Allow it in Settings.');
    }
    final Map<String, dynamic> res;
    try {
      res = await _post('/api/calls/${session.callId}/answer');
    } on CallFailure catch (e) {
      // Answered already by another screen of this app: close this duplicate
      // without touching the live call's audio or the system call UI.
      if (e.code == 'already_answered') return _drop(session);
      _log('answer failed callId=${session.callId}: ${e.message}');
      return _finish(session, e.statusCode == 409 ? 'This call has already ended' : e.message);
    }
    _log('answered callId=${session.callId}');
    session.answered(Map<String, dynamic>.from(res['call'] as Map)['remainingSeconds']);
    await _join(session, Map<String, dynamic>.from(res['zego'] as Map));
    if (session.phase != CallPhase.ended) FlutterCallkitIncoming.setCallConnected(session.callId).catchError((_) {});
  }

  // ---------------------------------------------------------------- in call

  Future<void> hangUp() async {
    final session = current.value;
    if (session == null || session.phase == CallPhase.ended) return;
    _log('hang up callId=${session.callId} phase=${session.phase.name}');
    // Show "Call ended" right away; the server confirms (409 = already over).
    final request = _post('/api/calls/${session.callId}/end').catchError((_) => <String, dynamic>{});
    await _finish(session, session.outgoing && session.phase != CallPhase.active ? 'Call cancelled' : 'Call ended');
    await request;
  }

  Future<void> toggleMute() async {
    final session = current.value;
    if (session == null) return;
    session.setMuted(!session.muted);
    if (_engineReady) await ZegoExpressEngine.instance.muteMicrophone(session.muted);
  }

  Future<void> toggleSpeaker() async {
    final session = current.value;
    if (session == null) return;
    session.setSpeaker(!session.speaker);
    if (_engineReady) await ZegoExpressEngine.instance.setAudioRouteToSpeaker(session.speaker);
  }

  // ---------------------------------------------------------------- events

  void _onSocket(SocketEvent event) {
    final data = event.data;
    final callId = data['id']?.toString();
    final session = current.value;
    final mine = session != null && session.callId == callId;
    if (event.name == 'chat_extended') {
      if (session != null && session.requestId == data['requestId']?.toString()) session.setTimeLeft(data['remainingSeconds']);
      return;
    }
    if (mine && event.name.startsWith('call_')) _log('server event ${event.name} callId=$callId status=${data['status']} endedBy=${data['endedBy']} reason=${data['endReason']}');
    switch (event.name) {
      case 'connect':
        _prepareDevice();
        _resumeAcceptedCalls();
      case 'incoming_call':
        if (data['receiverRole'] == _myRole && callId != null) {
          _ring(callId: callId, requestId: data['requestId'].toString(), callerName: data['callerName']?.toString() ?? 'Vakil', photoUrl: null);
        }
      case 'call_ringing':
        if (mine && session.phase == CallPhase.calling) session.setPhase(CallPhase.ringing);
      case 'call_answered':
        if (mine && session.outgoing) { session.answered(data['remainingSeconds']); }
        // Answered on another of my phones: stop ringing here.
        else if (!mine && callId != null && data['receiverRole'] == _myRole) { dismissIncomingCall(callId); }
      case 'call_rejected' || 'call_missed' || 'call_ended':
        if (callId == null) return;
        if (mine) {
          _finish(session, switch (event.name) {
            'call_rejected' => session.outgoing ? 'Call declined' : 'Call ended',
            'call_missed' => session.outgoing ? 'No answer' : 'Call ended',
            _ => data['status'] == 'failed' ? 'Call failed' : 'Call ended',
          });
        } else if (data['receiverRole'] == _myRole) {
          dismissIncomingCall(callId, missed: event.name == 'call_missed');
        }
    }
  }

  void _onCallkit(CallEvent? event) {
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        if (_sessionToken() == null) { _pendingAccepts.add(callKitParams); } else { _answer(callKitParams); }
      case CallEventActionCallDecline(:final callKitParams):
        _post('/api/calls/${callKitParams.id}/reject').catchError((_) => <String, dynamic>{});
      case CallEventActionCallEnded(:final callKitParams):
        // Ended from the ongoing-call notification.
        final session = current.value;
        if (session != null && session.callId == callKitParams.id && session.phase != CallPhase.ended) {
          _log('system call UI ended callId=${callKitParams.id}');
          hangUp();
        }
      default:
    }
  }

  /// A call accepted on the lock screen while the app was closed: answer it
  /// once the app has its session back.
  Future<void> _resumeAcceptedCalls() async {
    if (current.value != null || _sessionToken() == null) return;
    try {
      final accepted = [..._pendingAccepts, ...(await FlutterCallkitIncoming.activeCalls()).where((c) => c.isAccepted)];
      _pendingAccepts.clear();
      if (accepted.isNotEmpty) await _answer(accepted.first);
    } catch (e) {
      debugPrint('Could not resume accepted call: $e');
    }
  }

  /// Asks once per launch for what calls need: microphone, notifications and
  /// (Android 14+) showing the call full screen over the lock screen.
  Future<void> _prepareDevice() async {
    if (_devicePrepared) return;
    _devicePrepared = true;
    try {
      await Permission.microphone.request();
      await FlutterCallkitIncoming.requestNotificationPermission({'title': 'Notifications', 'rationaleMessagePermission': 'Vakil needs notifications to show incoming calls.', 'postNotificationMessageRequired': 'Allow notifications in Settings to receive calls.'});
      if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('asked_full_screen_calls') != true) {
          await prefs.setBool('asked_full_screen_calls', true);
          await FlutterCallkitIncoming.requestFullIntentPermission();
        }
      }
    } catch (e) {
      debugPrint('Call permissions: $e');
    }
  }

  // ---------------------------------------------------------------- audio

  Future<void> _join(CallSession session, Map<String, dynamic> zego) async {
    final roomId = zego['roomId'].toString();
    final userId = zego['userId'].toString();
    _log('join callId=${session.callId} room=$roomId userId=$userId appId=${zego['appId']}');
    try {
      if (!_engineReady) {
        await ZegoExpressEngine.createEngineWithProfile(ZegoEngineProfile((zego['appId'] as num).toInt(), ZegoScenario.StandardVoiceCall));
        _engineReady = true;
      }
      final engine = ZegoExpressEngine.instance;
      ZegoExpressEngine.onRoomStreamUpdate = (roomId, type, streams, _) {
        for (final stream in streams) {
          _log('remote stream ${type.name} ${stream.streamID}');
          type == ZegoUpdateType.Add ? engine.startPlayingStream(stream.streamID) : engine.stopPlayingStream(stream.streamID);
        }
      };
      ZegoExpressEngine.onRoomStateChanged = (roomId, reason, errorCode, _) {
        _log('room ${reason.name} error=$errorCode');
        if (reason == ZegoRoomStateChangedReason.LoginFailed || reason == ZegoRoomStateChangedReason.ReconnectFailed || reason == ZegoRoomStateChangedReason.KickOut) _fail(session, 'room_${reason.name}_$errorCode');
      };
      ZegoExpressEngine.onPublisherStateUpdate = (streamId, state, errorCode, _) => _log('my audio ${state.name} error=$errorCode');
      ZegoExpressEngine.onPlayerStateUpdate = (streamId, state, errorCode, _) => _log('their audio ${state.name} error=$errorCode');
      // The token lasts an hour; a longer call gets a fresh one before it runs out.
      ZegoExpressEngine.onRoomTokenWillExpire = (roomId, remainTimeInSecond) => _renewToken(session, roomId);
      await engine.enableCamera(false);
      final login = await engine.loginRoom(roomId, ZegoUser(userId, zego['userName']?.toString() ?? userId), config: ZegoRoomConfig(2, true, zego['token'].toString()));
      if (login.errorCode != 0) throw Exception('ZEGO login failed (${login.errorCode})');
      if (session.phase == CallPhase.ended) { await _leave(); return; }
      await engine.setAudioRouteToSpeaker(session.speaker);
      await engine.muteMicrophone(false);
      await engine.muteSpeaker(false);
      if (session.muted) await engine.muteMicrophone(true);
      await engine.startPublishingStream('${roomId}_$userId');
      _log('joined room=$roomId, publishing ${roomId}_$userId');
    } catch (e) {
      _log('audio failed: $e');
      _fail(session, 'join_error');
    }
  }

  Future<void> _renewToken(CallSession session, String roomId) async {
    try {
      final res = await _post('/api/calls/${session.callId}/token');
      await ZegoExpressEngine.instance.renewToken(roomId, Map<String, dynamic>.from(res['zego'] as Map)['token'].toString());
      _log('token renewed callId=${session.callId}');
    } catch (e) {
      _log('token renewal failed: $e');
    }
  }

  /// Audio could not connect: record a failed call (with why) and close the screen.
  void _fail(CallSession session, String reason) {
    if (session.phase == CallPhase.ended) return;
    _log('call failed callId=${session.callId} reason=$reason');
    _post('/api/calls/${session.callId}/end', {'failed': true, 'reason': reason}).catchError((_) => <String, dynamic>{});
    _finish(session, 'Call failed. Please check your connection.');
  }

  /// Closes a duplicate screen for a call that is live elsewhere in this app.
  void _drop(CallSession session) {
    _log('duplicate answer ignored callId=${session.callId}');
    session.end('');
    if (current.value != session) return;
    final route = _route;
    if (route != null && route.isActive) navigatorKey.currentState?.removeRoute(route);
    _route = null;
    current.value = null;
  }

  Future<void> _leave() async {
    if (!_engineReady) return;
    _engineReady = false;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateChanged = null;
    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
      await ZegoExpressEngine.instance.logoutRoom();
      // Releases the microphone completely.
      await ZegoExpressEngine.destroyEngine();
    } catch (e) {
      debugPrint('Call cleanup: $e');
    }
  }

  // ---------------------------------------------------------------- screen

  void _open(CallSession session) {
    current.value = session;
    final route = MaterialPageRoute<void>(builder: (_) => CallScreen(session: session));
    _route = route;
    navigatorKey.currentState?.push(route);
  }

  /// Shows why the call ended for a moment, then closes the call screen.
  Future<void> _finish(CallSession session, String message) async {
    if (session.phase == CallPhase.ended) return;
    _log('end callId=${session.callId}: $message');
    session.end(message);
    // Only the call on screen owns the audio engine, the system call UI and the screen.
    if (current.value != session) return;
    await _leave();
    FlutterCallkitIncoming.endCall(session.callId).catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final route = _route;
    if (route != null && route.isActive) navigatorKey.currentState?.removeRoute(route);
    _route = null;
    if (current.value == session) current.value = null;
    await _showOverLockScreen(false);
  }

  Future<void> _showOverLockScreen(bool on) async {
    try { await _window.invokeMethod('showOverLockScreen', on); } catch (_) {}
  }

  // ---------------------------------------------------------------- helpers

  Future<bool> _micAllowed() async => (await Permission.microphone.request()).isGranted;

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic> body = const {}]) => _postWith(_sessionToken(), path, body);
}

enum CallPhase { calling, ringing, connecting, active, ended }

/// One call as the screen shows it.
class CallSession extends ChangeNotifier {
  CallSession({required this.callId, required this.requestId, required this.otherName, this.otherPhotoUrl, required this.outgoing, required CallPhase phase}) : _phase = phase;
  final String callId;
  final String requestId;
  final String otherName;
  final String? otherPhotoUrl;
  final bool outgoing;
  CallPhase _phase;
  CallPhase get phase => _phase;
  bool muted = false;
  bool speaker = false;
  DateTime? answeredAt;
  // Local deadline from the server's remainingSeconds, so the phone clock doesn't matter.
  DateTime? endsAt;
  String? endMessage;

  int get talkSeconds => answeredAt == null ? 0 : DateTime.now().difference(answeredAt!).inSeconds;
  int? get secondsLeft { final s = endsAt?.difference(DateTime.now()).inSeconds; return s == null ? null : (s < 0 ? 0 : s); }

  void setPhase(CallPhase phase) { _phase = phase; notifyListeners(); }
  void setMuted(bool value) { muted = value; notifyListeners(); }
  void setSpeaker(bool value) { speaker = value; notifyListeners(); }
  void setTimeLeft(Object? remainingSeconds) { if (remainingSeconds is num) { endsAt = DateTime.now().add(Duration(seconds: remainingSeconds.toInt())); notifyListeners(); } }
  void answered(Object? remainingSeconds) { answeredAt = DateTime.now(); setTimeLeft(remainingSeconds); setPhase(CallPhase.active); }
  void end(String message) { endMessage = message; setPhase(CallPhase.ended); }
}

class CallFailure implements Exception {
  const CallFailure(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  /// The server's machine-readable reason, e.g. `already_answered`.
  final String? code;
}

// ------------------------------------------------------------------ background
// These run without the app's UI: in the FCM background isolate (app in the
// background, closed or phone locked) and in the call UI's background engine.

/// Shows the full-screen incoming call unless it is already showing.
/// Returns false when it was already on screen.
Future<bool> showIncomingCall({required String callId, required String requestId, required String callerName, String? photoUrl}) async {
  try {
    if ((await FlutterCallkitIncoming.activeCalls()).any((c) => c.id == callId)) return false;
  } catch (_) {}
  final avatar = photoUrl == null || photoUrl.isEmpty ? null : photoUrl.startsWith('/') ? '${ApiConfig.baseUrl}$photoUrl' : photoUrl;
  await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
    id: callId,
    nameCaller: callerName,
    appName: 'Vakil',
    avatar: avatar,
    handle: 'Vakil voice call',
    type: 0,
    duration: 30000,
    extra: {'requestId': requestId},
    missedCallNotification: const NotificationParams(showNotification: true, isShowCallback: false, subtitle: 'Missed voice call'),
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0F172A',
      actionColor: '#22C55E',
      textColor: '#FFFFFF',
      incomingCallNotificationChannelName: 'Incoming calls',
      missedCallNotificationChannelName: 'Missed calls',
      isShowFullLockedScreen: true,
      isImportant: true,
      textAccept: 'Accept',
      textDecline: 'Decline',
    ),
  ));
  return true;
}

/// Stops the ringing UI for a call that ended elsewhere; [missed] leaves a
/// "Missed voice call" notification.
Future<void> dismissIncomingCall(String callId, {bool missed = false}) async {
  try {
    final showing = (await FlutterCallkitIncoming.activeCalls()).where((c) => c.id == callId && !c.isAccepted).firstOrNull;
    if (showing == null) return;
    await FlutterCallkitIncoming.endCall(callId);
    if (missed) await FlutterCallkitIncoming.showMissCallNotification(showing);
  } catch (e) {
    debugPrint('Dismiss call UI: $e');
  }
}

/// Call pushes (FCM data) while the app is in the background or closed.
Future<void> handleCallPushInBackground(Map<String, dynamic> data) async {
  await ApiConfig.load();
  if (data['type'] == 'incoming_call') {
    // Decline taps are handled by [callUiBackgroundHandler] while the app is closed.
    await FlutterCallkitIncoming.onBackgroundMessage(callUiBackgroundHandler);
    if (await showIncomingCall(callId: data['callId'].toString(), requestId: data['requestId'].toString(), callerName: data['callerName']?.toString() ?? 'Vakil', photoUrl: data['callerPhotoUrl']?.toString())) {
      await _postWith(await _savedToken(), '/api/calls/${data['callId']}/ringing').catchError((_) => <String, dynamic>{});
    }
  } else if (data['type'] == 'call_ended') {
    await dismissIncomingCall(data['callId'].toString(), missed: data['status'] == 'missed');
  }
}

/// Call UI taps while no app screen is listening (app closed).
@pragma('vm:entry-point')
Future<void> callUiBackgroundHandler(CallEvent event) async {
  await ApiConfig.load();
  if (event is CallEventActionCallDecline) {
    await _postWith(await _savedToken(), '/api/calls/${event.callKitParams.id}/reject').catchError((_) => <String, dynamic>{});
  }
}

Future<String?> _savedToken() async {
  try { return (await SharedPreferences.getInstance()).getString(_tokenKey); } catch (_) { return null; }
}

Future<Map<String, dynamic>> _postWith(String? token, String path, [Map<String, dynamic> body = const {}]) async {
  if (token == null) throw const CallFailure('Please sign in again');
  try {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}$path'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(body)).timeout(ApiConfig.requestTimeout);
    Map<String, dynamic> data = {};
    try { data = Map<String, dynamic>.from(jsonDecode(response.body) as Map); } catch (_) {}
    if (response.statusCode >= 400) throw CallFailure(data['error']?.toString() ?? 'Call failed. Please try again.', statusCode: response.statusCode, code: data['code']?.toString());
    return data;
  } on CallFailure {
    rethrow;
  } catch (_) {
    throw const CallFailure('Server not reachable, please try again');
  }
}
