import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/active_consultation_chat_screen.dart';
import '../screens/incoming_request_screen.dart';
import '../services/alert_service.dart';
import '../services/app_keys.dart';
import '../services/partner_auth_service.dart';
import '../services/push_service.dart';
import '../services/registration_sync.dart';
import '../services/realtime_service.dart';
import '../services/consultation_service.dart';

enum ConsultationType { chat, voice }

class ConsultationRequest {
  final String id;
  final String clientName;
  final String initials;
  final String lastSeen;
  final String problemSummary;
  final ConsultationType type;
  final int pricePerMinute;
  final int maxMinutes;
  final String category;
  final int documentsAttached;
  final String documentName;
  final int expiresInSeconds;
  final bool isTrial;
  final DateTime? expiresAt;
  /// The client's profile photo ("/uploads/…"), if they added one.
  final String? photoUrl;

  const ConsultationRequest({
    required this.id,
    required this.clientName,
    required this.initials,
    required this.lastSeen,
    required this.problemSummary,
    required this.type,
    required this.pricePerMinute,
    required this.maxMinutes,
    required this.category,
    this.documentsAttached = 0,
    this.documentName = 'document.pdf',
    this.expiresInSeconds = 300,
    this.isTrial = false,
    this.expiresAt,
    this.photoUrl,
  });

  /// Seconds left before the server expires the request (60 s from creation).
  int get secondsLeft => expiresAt == null ? expiresInSeconds : expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 60).toInt();

  String get typeLabel => type == ConsultationType.chat ? 'Chat only' : 'Voice only';

  String get clientRef => '#VP-${(id.hashCode.abs() % 9000) + 1000}';
}

class CallLogEntry {
  final String clientName;
  final String referenceId;
  final DateTime time;
  final double amount;
  final String category;
  final Duration duration;

  const CallLogEntry({
    required this.clientName,
    required this.referenceId,
    required this.time,
    required this.amount,
    required this.category,
    required this.duration,
  });
}

/// Static demo profile shown on the dashboard. In a real app this would come
/// from the authenticated advocate's account rather than being hardcoded.
class LawyerProfile {
  static const rating = 4.8;
  static const ratingCount = 120;
}

class PracticeAreaOption {
  final String title;
  final String description;
  const PracticeAreaOption(this.title, this.description);
}

const kPracticeAreaOptions = [
  PracticeAreaOption('Criminal law', 'General criminal defence and case support'),
  PracticeAreaOption('Traffic violations', 'Challans, fines, and traffic court matters'),
  PracticeAreaOption('Drunk-driving cases', 'DUI and related legal proceedings'),
  PracticeAreaOption('Motor accident claims', 'Compensation and insurance claim disputes'),
  PracticeAreaOption('Bail and police arrest', 'Bail filings and police custody support'),
  PracticeAreaOption('Family and divorce law', 'Marriage, divorce, and custody matters'),
  PracticeAreaOption('Property disputes', 'Ownership, partition, and title conflicts'),
  PracticeAreaOption('Consumer complaints', 'Service, product, and refund disputes'),
  PracticeAreaOption('Cybercrime and online fraud', 'Digital fraud, harassment, and cyber cases'),
  PracticeAreaOption('Employment disputes', 'Workplace, salary, and termination issues'),
  PracticeAreaOption('Business and startup law', 'Company setup, contracts, and compliance'),
  PracticeAreaOption('Documentation and legal notices', 'Drafting, notices, and document review'),
];

/// Today's numbers on the home screen, from GET /api/lawyers/me/earnings.
class DashboardStats {
  final int consultationsToday;
  /// What the lawyer earned today (client payments minus commission).
  final double earningsToday;
  final int minutesToday;
  /// Calls not picked up and chat requests not answered in time.
  final int missedToday;

  const DashboardStats({
    required this.consultationsToday,
    required this.earningsToday,
    required this.minutesToday,
    required this.missedToday,
  });

  static const empty = DashboardStats(consultationsToday: 0, earningsToday: 0, minutesToday: 0, missedToday: 0);

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        consultationsToday: (json['consultations'] as num?)?.toInt() ?? 0,
        earningsToday: (json['earnings'] as num?)?.toDouble() ?? 0,
        minutesToday: (json['minutes'] as num?)?.toInt() ?? 0,
        missedToday: (json['missed'] as num?)?.toInt() ?? 0,
      );
}

class FinancialSummary {
  final double pendingPayout;
  final double completedPayouts;

  const FinancialSummary({
    required this.pendingPayout,
    required this.completedPayouts,
  });

  static const empty = FinancialSummary(pendingPayout: 0, completedPayouts: 0);
}

/// ₹ amounts without ".0" for whole rupees (₹40, ₹40.50).
String rupees(num value) => '₹${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(2)}';

/// Holds mutable dashboard state (availability toggles, incoming requests)
/// so the Dashboard and Requests screens stay in sync.
class DashboardController extends ChangeNotifier {
  final PartnerConsultationService consultationService = PartnerConsultationService();
  String? _token;
  String? get token => _token;
  StreamSubscription<SocketEvent>? _events;
  Timer? _expirySweep;
  /// Client names by request id, for new-message banners.
  final Map<String, String> _chatNames = {};

  /// Called after sign-in: listens for requests and messages, loads pending
  /// requests, marks the lawyer online and registers the phone for pushes.
  Future<void> connectBackend(String token) async {
    if (_token == token) return;
    _token = token;
    await _events?.cancel();
    _events = RealtimeService.instance.events.stream.listen(_onEvent);
    // Requests that expire while no event arrives still stop ringing.
    _expirySweep?.cancel();
    _expirySweep = Timer.periodic(const Duration(seconds: 1), (_) {
      if (requests.any((r) => r.expiresAt != null && r.secondsLeft <= 0)) { requests.removeWhere((r) => r.expiresAt != null && r.secondsLeft <= 0); _afterRequestsChanged(); }
    });
    await loadAvailability();
    await refreshRequests();
    loadEarnings();
    PushService.instance.registerDevice(token);
    RegistrationSync.flush(token);
  }

  Future<void> refreshRequests() async {
    final token = _token;
    if (token == null) return;
    try {
      final data = await consultationService.list(token);
      final pending = (data['items'] as List? ?? const []).map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
      requests.removeWhere((r) => r.expiresAt != null && !pending.any((p) => p['id'] == r.id));
      for (final raw in pending) { _upsertNetworkRequest(raw, announce: false); }
      _afterRequestsChanged();
    } catch (error) {
      debugPrint('Could not load requests: $error');
    }
  }

  void _onEvent(SocketEvent event) {
    switch (event.name) {
      case 'connect':
        refreshRequests();
        loadAvailability();
        loadEarnings();
      case 'earnings_updated' || 'chat_ended' || 'call_missed':
        // Money came in, a chat finished (minutes) or a call was missed.
        loadEarnings();
      case 'new_request' || 'status_updated':
        _upsertNetworkRequest(event.data, announce: event.name == 'new_request');
        if (event.data['status'] == 'EXPIRED') loadEarnings();
      case 'new_message':
        if (event.data['senderRole'] == 'user') _onClientMessage(event.data);
    }
  }

  void _upsertNetworkRequest(Map<String, dynamic> raw, {bool announce = true}) {
    final status = raw['status']?.toString();
    final id = raw['id'].toString();
    final isNew = !requests.any((item) => item.id == id);
    requests.removeWhere((item) => item.id == id);
    if (status == 'ONGOING') _chatNames[id] = raw['userName']?.toString() ?? 'Client';
    if (status != 'PENDING') { _afterRequestsChanged(); return; }
    final expiresAt = DateTime.tryParse(raw['expiresAt']?.toString() ?? '')?.toLocal();
    final clientName = raw['userName']?.toString() ?? 'Client';
    final request = ConsultationRequest(id: id, clientName: clientName, initials: clientName.isEmpty ? '?' : clientName[0].toUpperCase(), lastSeen: 'Just now', problemSummary: raw['description']?.toString() ?? '', type: raw['consultationType'] == 'call' ? ConsultationType.voice : ConsultationType.chat, pricePerMinute: ((raw['ratePerMinute'] as num?) ?? 0).round(), maxMinutes: (raw['chatMinutes'] as num?)?.toInt() ?? 0, category: raw['category']?.toString() ?? 'General', expiresInSeconds: 60, isTrial: raw['isTrial'] == true, expiresAt: expiresAt, photoUrl: raw['userPhotoUrl'] as String?);
    if (request.secondsLeft <= 0) { _afterRequestsChanged(); return; }
    requests.insert(0, request);
    _afterRequestsChanged();
    // Show the request full screen when it arrives (unless one is already showing).
    if (announce && isNew && OpenScreens.incomingRequestId == null) {
      navigatorKey.currentState?.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => IncomingRequestScreen(request: request)));
    }
  }

  /// Rings while any request is waiting; stops on accept, reject, expiry or cancel.
  void _afterRequestsChanged() {
    if (requests.isEmpty) { AlertService.instance.stopRequestRing(); } else { AlertService.instance.startRequestRing(); }
    notifyListeners();
  }

  Future<void> _onClientMessage(Map<String, dynamic> message) async {
    final requestId = message['requestId']?.toString();
    if (requestId == null) return;
    // Softer ding for the chat on screen; ding + banner anywhere else.
    if (OpenScreens.chatRequestId == requestId) { AlertService.instance.messageDing(soft: true); return; }
    AlertService.instance.messageDing();
    var name = _chatNames[requestId];
    if (name == null && _token != null) {
      try { name = _chatNames[requestId] = (await consultationService.chat(requestId, _token!)).other.name; } catch (_) {}
    }
    final text = message['type'] == 'call' ? '📞 ${message['text']}' : message['text']?.toString() ?? '';
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text('${name ?? 'Client'}: $text', maxLines: 2, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'Open', onPressed: () => openChat(requestId, name ?? 'Client')),
      ));
  }

  void openChat(String requestId, String clientName) {
    if (OpenScreens.chatRequestId == requestId) return;
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ActiveConsultationChatScreen(requestId: requestId, title: clientName)));
  }

  /// Opens the screen a notification points to (new request or chat).
  Future<void> openFromPush(Map<String, dynamic> data) async {
    final requestId = data['requestId']?.toString();
    if (requestId == null) return;
    if (data['type'] == 'new_request') {
      await refreshRequests();
      final request = requests.where((r) => r.id == requestId).firstOrNull;
      if (request != null && OpenScreens.incomingRequestId == null) navigatorKey.currentState?.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => IncomingRequestScreen(request: request)));
    } else {
      openChat(requestId, _chatNames[requestId] ?? 'Client');
    }
  }

  /// Accepts a request. Returns false (and drops it quietly) when it was
  /// already accepted, rejected, cancelled or expired — the server's 409.
  Future<bool> acceptRequest(String id) async {
    if (_token == null) throw StateError('Not signed in');
    final request = requests.where((r) => r.id == id).firstOrNull;
    try {
      await consultationService.accept(id, _token!);
      _chatNames[id] = request?.clientName ?? 'Client';
      removeRequest(id);
      return true;
    } on PartnerNetworkException catch (error) {
      if (error.statusCode == 409 || error.statusCode == 404) { removeRequest(id); return false; }
      rethrow;
    }
  }

  Future<void> rejectRequest(String id) async {
    if (_token == null) throw StateError('Not signed in');
    try {
      await consultationService.reject(id, _token!);
    } on PartnerNetworkException catch (error) {
      if (error.statusCode != 409 && error.statusCode != 404) rethrow;
    }
    removeRequest(id);
  }

  void disconnect() {
    _events?.cancel();
    _events = null;
    _expirySweep?.cancel();
    _token = null;
    requests.clear();
    AlertService.instance.stopRequestRing();
    notifyListeners();
  }

  /// The lawyer's switches (saved on the server, shown to users live).
  bool availableForChat = false;
  bool availableForCall = false;
  /// Whether the Vakil admin allows chat / calls for this lawyer.
  bool chatAllowed = true;
  bool callAllowed = true;
  /// Online = taking chats or calls.
  bool get onlineStatus => availableForChat || availableForCall;
  List<String> practiceAreas = ['Corporate law'];

  /// Today's numbers and payouts, from the server (see [loadEarnings]).
  DashboardStats stats = DashboardStats.empty;
  FinancialSummary financials = FinancialSummary.empty;

  /// Refreshes today's numbers after each payment, finished chat or missed call.
  Future<void> loadEarnings() async {
    final token = _token;
    if (token == null) return;
    try {
      final data = await consultationService.earnings(token);
      stats = DashboardStats.fromJson(Map<String, dynamic>.from(data['today'] as Map? ?? const {}));
      financials = FinancialSummary(pendingPayout: (data['pendingPayouts'] as num?)?.toDouble() ?? 0, completedPayouts: (data['paidOut'] as num?)?.toDouble() ?? 0);
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load earnings: $error');
    }
  }

  final List<ConsultationRequest> requests = [];

  /// Loads the switches from the server (they may have been turned off while
  /// the app was closed for a while).
  Future<void> loadAvailability() async {
    final token = _token;
    if (token == null) return;
    try {
      final data = await consultationService.getAvailability(token);
      availableForChat = data['isChatOnline'] == true;
      availableForCall = data['isCallOnline'] == true;
      final channels = Map<String, dynamic>.from(data['channels'] as Map? ?? const {});
      chatAllowed = channels['chat'] != false;
      callAllowed = channels['call'] != false;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load availability: $error');
    }
  }

  /// Online / offline for both chat and calls (Settings).
  Future<void> setOnlineStatus(bool value) => _saveAvailability(chat: value, call: value);
  Future<void> setAvailableForChat(bool value) => _saveAvailability(chat: value, call: availableForCall);
  Future<void> setAvailableForCall(bool value) => _saveAvailability(chat: availableForChat, call: value);

  /// Saves both switches; users see the change at once. Reverts if it fails.
  Future<void> _saveAvailability({required bool chat, required bool call}) async {
    final chatBefore = availableForChat; final callBefore = availableForCall;
    availableForChat = chat;
    availableForCall = call;
    notifyListeners();
    if (_token == null) return;
    try {
      final saved = await consultationService.setAvailability(_token!, chat: chat, call: call);
      availableForChat = saved['isChatOnline'] == true;
      availableForCall = saved['isCallOnline'] == true;
      notifyListeners();
    } catch (error) {
      availableForChat = chatBefore; availableForCall = callBefore;
      notifyListeners();
      messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Could not change your availability. Please try again.')));
    }
  }

  void setPracticeAreas(List<String> values) {
    practiceAreas = values;
    notifyListeners();
  }

  void removeRequest(String id) {
    requests.removeWhere((r) => r.id == id);
    _afterRequestsChanged();
  }

  final List<CallLogEntry> callLogs = [
    CallLogEntry(
      clientName: 'Suresh Gupta',
      referenceId: 'VP-CALL-8822',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      amount: 1125,
      category: 'Family',
      duration: const Duration(minutes: 25, seconds: 10),
    ),
    CallLogEntry(
      clientName: 'Noha Sharma',
      referenceId: 'VP-CALL-6710',
      time: DateTime.now().subtract(const Duration(days: 4)),
      amount: 360,
      category: 'Corporate',
      duration: const Duration(minutes: 8, seconds: 15),
    ),
    CallLogEntry(
      clientName: 'Vikram Malhotra',
      referenceId: 'VP-CALL-9541',
      time: DateTime.now().subtract(const Duration(days: 6)),
      amount: 810,
      category: 'Criminal',
      duration: const Duration(minutes: 18, seconds: 30),
    ),
  ];

  void addCallLog(CallLogEntry entry) {
    callLogs.insert(0, entry);
    notifyListeners();
  }

  ConsultationRequest addDemoRequest() {
    final demo = ConsultationRequest(
      id: 'req-${DateTime.now().millisecondsSinceEpoch}',
      clientName: 'Aniket',
      initials: 'A',
      lastSeen: 'Just now',
      problemSummary:
          'Ancestral property partition deed is being challenged by siblings. Need a quick review of share and registration dates.',
      type: ConsultationType.chat,
      pricePerMinute: 40,
      maxMinutes: 32,
      category: 'Property Law',
      documentsAttached: 1,
      documentName: 'partition_deed.pdf',
      expiresInSeconds: 10,
    );
    requests.insert(0, demo);
    notifyListeners();
    return demo;
  }

  ConsultationRequest addDemoVoiceRequest() {
    final demo = ConsultationRequest(
      id: 'req-${DateTime.now().millisecondsSinceEpoch}',
      clientName: 'Ramesh Kumar',
      initials: 'RK',
      lastSeen: 'Just now',
      problemSummary: 'Property case — needs urgent advice on a boundary dispute with a neighbour.',
      type: ConsultationType.voice,
      pricePerMinute: 45,
      maxMinutes: 20,
      category: 'Property Case',
      expiresInSeconds: 10,
    );
    requests.insert(0, demo);
    notifyListeners();
    return demo;
  }
}
