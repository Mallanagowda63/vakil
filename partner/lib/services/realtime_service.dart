import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';

class SocketEvent {
  const SocketEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
}

/// A message typed while offline (or not yet acknowledged). It keeps its
/// clientId across retries, so the server never stores it twice.
class PendingMessage {
  PendingMessage(this.requestId, this.clientId, this.text) : createdAt = DateTime.now();
  final String requestId;
  final String clientId;
  final String text;
  final DateTime createdAt;
  bool failed = false;
  String? error;
}

class RealtimeOffline implements Exception { const RealtimeOffline(); }

/// The app's single Socket.IO connection. Screens listen to [events]; the
/// REST API stays the source of truth and screens re-fetch after [connect].
class RealtimeService with WidgetsBindingObserver {
  RealtimeService._();
  static final instance = RealtimeService._();

  static const _serverEvents = [
    'new_request', 'request_accepted', 'request_rejected', 'request_expired', 'request_cancelled', 'request_completed', 'status_updated',
    'new_message', 'message_delivered', 'message_read', 'typing_start', 'typing_stop', 'user_online', 'user_offline', 'chat_ended',
    'incoming_call', 'call_ringing', 'call_answered', 'call_rejected', 'call_ended', 'call_missed',
    'chat_extended', 'earnings_updated',
  ];

  io.Socket? _socket;
  String? _token;
  String? _url;
  bool _followsServer = false;
  final events = StreamController<SocketEvent>.broadcast();
  final connected = ValueNotifier<bool>(false);
  final outbox = <PendingMessage>[];
  /// Emits the requestId whose outbox entries changed.
  final outboxChanged = StreamController<String>.broadcast();
  final _random = Random();
  bool _flushing = false;
  Timer? _watchdog;
  DateTime? _offlineSince;
  bool _observing = false;

  void connect(String token) {
    if (_token == token && _socket != null && _url == ApiConfig.socketUrl) return;
    // The same account at a new server address keeps its unsent messages.
    if (_token == token) {
      _socket?.dispose();
    } else {
      disconnect();
    }
    if (!_followsServer) {
      _followsServer = true;
      ApiConfig.changes.addListener(() { final current = _token; if (current != null) connect(current); });
    }
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _token = token;
    _offlineSince = DateTime.now();
    _watchdog ??= Timer.periodic(const Duration(seconds: 4), (_) => _checkAlive());
    final url = _url = ApiConfig.socketUrl;
    // forceNew: a socket rebuilt for the same address must not reuse the old, closed connection.
    final socket = io.io(url, io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableReconnection().enableForceNew().disableAutoConnect().build());
    for (final name in _serverEvents) {
      socket.on(name, (data) => _onEvent(name, data));
    }
    socket.onConnect((_) {
      connected.value = true;
      _offlineSince = null;
      events.add(const SocketEvent('connect', {}));
      _flushOutbox();
    });
    socket.onDisconnect((_) {
      connected.value = false;
      _offlineSince ??= DateTime.now();
    });
    socket.onConnectError((error) {
      debugPrint('Socket connect error: $error');
      ApiConfig.findServer();
    });
    _socket = socket..connect();
  }

  /// Android pauses an app in the background (e.g. while the other Vakil app
  /// is open on the same phone) and its socket can stay dead afterwards, so a
  /// socket that has not connected for a while is replaced with a fresh one.
  void _rebuild() {
    final token = _token;
    if (token == null) return;
    _socket?.dispose();
    _socket = null;
    connect(token);
  }

  void _checkAlive() {
    final since = _offlineSince;
    if (_token == null || connected.value || since == null) return;
    if (DateTime.now().difference(since) > const Duration(seconds: 8)) {
      ApiConfig.findServer();
      _rebuild();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _token != null && !connected.value) _rebuild();
  }

  void disconnect() {
    _watchdog?.cancel();
    _watchdog = null;
    _offlineSince = null;
    _socket?.dispose();
    _socket = null;
    _token = null;
    _url = null;
    connected.value = false;
    outbox.clear();
  }

  void _onEvent(String name, dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    // A client's message reached this phone: tell the client it was delivered.
    if (name == 'new_message' && map['senderRole'] == 'user' && map['id'] != null) {
      emit('message_delivered', {'requestId': map['requestId'], 'messageIds': [map['id']]});
    }
    events.add(SocketEvent(name, map));
  }

  void emit(String event, Map<String, dynamic> data) => _socket?.emit(event, data);

  /// Emits with an acknowledgement; the server answers { ok, ... } or { ok: false, error, status }.
  Future<Map<String, dynamic>> request(String event, Map<String, dynamic> data, {Duration timeout = const Duration(seconds: 10)}) {
    final socket = _socket;
    if (socket == null || !socket.connected) return Future.error(const RealtimeOffline());
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(event, data, ack: (response) {
      if (!completer.isCompleted) completer.complete(response is Map ? Map<String, dynamic>.from(response) : {'ok': false, 'status': 500});
    });
    return completer.future.timeout(timeout);
  }

  /// Queues a message and sends it now if online, otherwise on reconnect.
  PendingMessage send(String requestId, String text) {
    final pending = PendingMessage(requestId, 'c${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1 << 20)}', text);
    outbox.add(pending);
    outboxChanged.add(requestId);
    _flushOutbox();
    return pending;
  }

  void retry(PendingMessage pending) {
    pending.failed = false;
    pending.error = null;
    outboxChanged.add(pending.requestId);
    _flushOutbox();
  }

  /// Sends queued messages in order. A refusal (e.g. chat ended) marks that
  /// message failed; a network problem stops and waits for the next connect.
  Future<void> _flushOutbox() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (connected.value) {
        final next = outbox.where((p) => !p.failed).firstOrNull;
        if (next == null) break;
        try {
          final response = await request('send_message', {'requestId': next.requestId, 'text': next.text, 'clientId': next.clientId});
          if (response['ok'] == true) {
            outbox.remove(next);
            events.add(SocketEvent('new_message', Map<String, dynamic>.from(response['message'] as Map)));
          } else if (((response['status'] as num?) ?? 500) < 500) {
            next.failed = true;
            next.error = response['error']?.toString();
          } else {
            break;
          }
        } on TimeoutException {
          break;
        } on RealtimeOffline {
          break;
        } finally {
          outboxChanged.add(next.requestId);
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
