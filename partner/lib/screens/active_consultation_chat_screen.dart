import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../services/app_keys.dart';
import '../services/call_service.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../utils/chat_format.dart';
import 'consultation_summary_screen.dart';

/// One chat with a client — the same chat UI as the User App. Messages go
/// through RealtimeService (queued while offline); the REST API reloads the
/// truth on open, reconnect and resume. A chat ended elsewhere (client,
/// trial timer) just switches to read-only, quietly.
class ActiveConsultationChatScreen extends StatefulWidget {
  const ActiveConsultationChatScreen({super.key, required this.requestId, required this.title});
  final String requestId;
  final String title;
  @override
  State<ActiveConsultationChatScreen> createState() => _State();
}

class _State extends State<ActiveConsultationChatScreen> with WidgetsBindingObserver {
  final _service = PartnerConsultationService();
  final _realtime = RealtimeService.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  final _ids = <String>{};
  StreamSubscription<SocketEvent>? _events;
  StreamSubscription<String>? _outbox;
  Timer? _ticker;
  Timer? _typingClear;
  Timer? _typingIdle;
  ChatSummary? _chat;
  String? _error;
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingOlder = false;
  bool _clientTyping = false;
  bool _iAmTyping = false;
  bool _otherOnline = false;
  DateTime? _lastSeen;
  String _status = 'ONGOING';
  bool _isTrial = false;
  // Local deadline from the server's remainingSeconds, so the phone clock doesn't matter.
  DateTime? _endsAt;
  // When the chat started, from the server's elapsedSeconds (phone clock doesn't matter).
  DateTime? _startedAt;
  // True once this chat showed a countdown, so its end reads "Chat time is over".
  bool _timed = false;
  bool _foreground = true;

  String get _id => widget.requestId;
  String? get _token => PartnerAuthService.instance.token;
  int? get _remaining { final s = _endsAt?.difference(DateTime.now()).inSeconds; return s == null ? null : (s < 0 ? 0 : s); }
  bool get _ended => _status != 'ONGOING' || _remaining == 0;

  @override
  void initState() {
    super.initState();
    OpenScreens.chatRequestId = _id;
    WidgetsBinding.instance.addObserver(this);
    _events = _realtime.events.stream.listen(_onEvent);
    _outbox = _realtime.outboxChanged.stream.where((id) => id == _id).listen((_) { if (mounted) setState(() {}); });
    _scroll.addListener(_maybeLoadOlder);
    _load();
  }

  @override
  void dispose() {
    if (OpenScreens.chatRequestId == _id) OpenScreens.chatRequestId = null;
    WidgetsBinding.instance.removeObserver(this);
    if (_iAmTyping) _realtime.emit('typing_stop', {'requestId': _id});
    _events?.cancel();
    _outbox?.cancel();
    _ticker?.cancel();
    _typingClear?.cancel();
    _typingIdle?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _resync();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    try {
      final chat = await _service.chat(_id, token);
      final page = await _service.messages(_id, token);
      if (!mounted) return;
      setState(() {
        _applyChat(chat);
        _messages..clear()..addAll(page.items);
        _ids..clear()..addAll(page.items.map((m) => m.id));
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
      _realtime.emit('join_chat', {'requestId': _id});
      _markRead();
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  /// After a reconnect or coming back to the foreground: refresh status,
  /// the trial clock and presence, and fetch messages missed meanwhile.
  Future<void> _resync() async {
    final token = _token;
    if (_loading || token == null) return;
    try {
      final chat = await _service.chat(_id, token);
      final last = _messages.isEmpty ? null : _messages.last.id;
      final missed = last == null ? await _service.messages(_id, token) : await _service.messages(_id, token, after: last);
      if (!mounted) return;
      setState(() { _applyChat(chat); for (final m in missed.items) { _insert(m); } });
      _realtime.emit('join_chat', {'requestId': _id});
      _markRead();
    } catch (_) {}
  }

  void _applyChat(ChatSummary chat) {
    // Seen ending while open (e.g. after a reconnect): show the summary.
    if (_chat != null && _status == 'ONGOING' && !chat.isOngoing) _openSummary();
    _chat = chat;
    _status = chat.status;
    _isTrial = chat.isTrial;
    _otherOnline = chat.other.online;
    _lastSeen = chat.other.lastSeenAt;
    _endsAt = chat.isOngoing && chat.remainingSeconds != null ? DateTime.now().add(Duration(seconds: chat.remainingSeconds!)) : null;
    if (chat.remainingSeconds != null) _timed = true;
    _startedAt = chat.isOngoing && chat.elapsedSeconds != null ? DateTime.now().subtract(Duration(seconds: chat.elapsedSeconds!)) : null;
    _ticker?.cancel();
    if (chat.isOngoing) _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted) return; setState(() {}); if (_ended) _ticker?.cancel(); });
  }

  void _insert(ChatMessage message) {
    if (!_ids.add(message.id)) return;
    _messages.add(message);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _markRead() {
    final unread = _messages.where((m) => m.senderRole == 'user' && m.status != MessageStatus.read).toList();
    if (!_foreground || unread.isEmpty) return;
    _realtime.emit('message_read', {'requestId': _id});
    for (final m in unread) {
      m.status = MessageStatus.read;
    }
  }

  void _onEvent(SocketEvent event) {
    final data = event.data;
    if (event.name == 'connect') { _resync(); return; }
    // Presence events carry the client's id, not the request id.
    if ((event.name == 'user_online' || event.name == 'user_offline') && data['id']?.toString() == _chat?.other.id) {
      if (mounted) setState(() { _otherOnline = event.name == 'user_online'; _lastSeen = DateTime.tryParse(data['lastSeenAt']?.toString() ?? '')?.toLocal() ?? _lastSeen; });
      return;
    }
    final forThisChat = data['requestId']?.toString() == _id || data['id']?.toString() == _id;
    if (!forThisChat || !mounted) return;
    switch (event.name) {
      case 'new_message':
        final message = ChatMessage.fromJson(data);
        setState(() { _insert(message); if (message.senderRole == 'user') _clientTyping = false; });
        if (message.senderRole == 'user') _markRead();
        _scrollToBottom();
      case 'message_delivered' || 'message_read':
        final ids = (data['messageIds'] as List? ?? const []).map((e) => e.toString()).toSet();
        final status = event.name == 'message_read' ? MessageStatus.read : MessageStatus.delivered;
        setState(() { for (final m in _messages) { if (m.senderRole == 'lawyer' && ids.contains(m.id) && m.status.index < status.index) m.status = status; } });
      case 'typing_start' || 'typing_stop':
        if (data['role'] != 'user') return;
        setState(() => _clientTyping = event.name == 'typing_start');
        _typingClear?.cancel();
        if (_clientTyping) _typingClear = Timer(const Duration(seconds: 6), () { if (mounted) setState(() => _clientTyping = false); });
      case 'chat_extended':
        // The client bought more time.
        final seconds = (data['remainingSeconds'] as num?)?.toInt();
        if (seconds == null) return;
        setState(() => _endsAt = DateTime.now().add(Duration(seconds: seconds)));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('The client added ${data['minutesAdded']} min')));
      case 'chat_ended' || 'status_updated':
        if (event.name == 'status_updated' && data['status'] != 'COMPLETED') return;
        final wasOngoing = _status == 'ONGOING';
        setState(() { _status = 'COMPLETED'; _endsAt = null; });
        _ticker?.cancel();
        if (wasOngoing) _openSummary();
    }
  }

  Future<void> _maybeLoadOlder() async {
    final token = _token;
    if (token == null || !_hasMore || _loadingOlder || _messages.isEmpty || _scroll.position.pixels < _scroll.position.maxScrollExtent - 200) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _service.messages(_id, token, before: _messages.first.id);
      if (mounted) setState(() { for (final m in page.items) { _insert(m); } _hasMore = page.hasMore; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onTyping(String text) {
    if (_ended) return;
    if (text.trim().isNotEmpty && !_iAmTyping) { _iAmTyping = true; _realtime.emit('typing_start', {'requestId': _id}); }
    _typingIdle?.cancel();
    _typingIdle = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (!_iAmTyping) return;
    _iAmTyping = false;
    _realtime.emit('typing_stop', {'requestId': _id});
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _ended) return;
    _input.clear();
    _stopTyping();
    _realtime.send(_id, text);
    _scrollToBottom();
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut); });

  bool _summaryOpened = false;
  /// The chat just ended: show what it cost and earned. Waits for a call
  /// screen that ends with the chat to close first.
  void _openSummary() {
    if (_summaryOpened) return;
    _summaryOpened = true;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsultationSummaryScreen(requestId: _id, clientName: _chat?.other.name ?? widget.title)));
    });
  }

  Future<void> _startCall() async {
    final error = await CallService.instance.startCall(requestId: _id, otherName: _chat?.other.name ?? widget.title, otherPhotoUrl: _chat?.other.photoUrl);
    if (error != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _confirmEnd() async {
    final token = _token;
    if (token == null) return;
    final end = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('End chat?'),
      content: Text('${_chat?.other.name ?? widget.title} will not be able to send more messages.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Chat'))],
    ));
    if (end != true) return;
    try {
      await _service.complete(_id, token);
    } on PartnerNetworkException catch (e) {
      // 409: already ended by the client or the timer; the refresh shows it.
      if (e.statusCode != 409 && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    await _resync();
  }

  String get _subtitle {
    if (_ended) return 'Chat ended';
    if (_clientTyping) return 'typing...';
    return _otherOnline ? 'Online' : lastSeenLabel(_lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    final name = _chat?.other.name ?? widget.title;
    final pending = _realtime.outbox.where((p) => p.requestId == _id && !_messages.any((m) => m.clientId == p.clientId)).toList();
    // Newest first for the reversed list.
    final items = <Object>[...pending.reversed, ..._messages.reversed];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          ClientAvatar(name: name, photoUrl: _chat?.other.photoUrl, online: _otherOnline && !_ended),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(_subtitle, style: TextStyle(fontSize: 12, color: _clientTyping && !_ended ? AppColors.success : AppColors.textSecondary)),
          ])),
        ]),
        actions: [
          IconButton(tooltip: 'Voice call', onPressed: _ended || _loading ? null : _startCall, icon: const Icon(Icons.call_outlined)),
          if (!_ended && !_isTrial && !_loading)
            PopupMenuButton<String>(onSelected: (_) => _confirmEnd(), itemBuilder: (_) => const [PopupMenuItem(value: 'end', child: Text('End Chat'))]),
        ],
      ),
      body: Column(children: [
        ValueListenableBuilder<bool>(
          valueListenable: _realtime.connected,
          builder: (_, online, __) => online ? const SizedBox.shrink() : Container(width: double.infinity, color: const Color(0xFFFFF3CD), padding: const EdgeInsets.symmetric(vertical: 4), child: const Text('Connecting…', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
        ),
        // Countdown to the chat's end (2:00 → 0:00, trial 1:00 → 0:00); older chats without a limit count up.
        if (!_ended && _remaining != null) ...[
          _TrialBar(seconds: _remaining!, trial: _isTrial),
          // The last minute: the chat and any call end unless the client adds time.
          if (_remaining! <= 60) Container(
            width: double.infinity,
            color: const Color(0xFFFFF3CD),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Text('Less than 1 minute left. The client can add more time.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]
        else if (!_ended && _startedAt != null) _ChatClock(seconds: DateTime.now().difference(_startedAt!).inSeconds),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Try again'))]))
                : items.isEmpty
                    ? Center(child: Text(_ended ? 'This chat has ended.' : 'Chat started. Say hello to $name.', style: const TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length + (_loadingOlder ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == items.length) return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                          final item = items[i];
                          final time = item is ChatMessage ? item.createdAt : (item as PendingMessage).createdAt;
                          final older = i + 1 < items.length ? items[i + 1] : null;
                          final olderTime = older == null ? null : older is ChatMessage ? older.createdAt : (older as PendingMessage).createdAt;
                          final showDay = olderTime == null || !sameDay(time, olderTime);
                          return Column(children: [
                            if (showDay) _DaySeparator(label: dayLabel(time)),
                            item is ChatMessage ? (item.isCall ? _CallEntry(message: item) : _Bubble.fromMessage(item)) : _Bubble.fromPending(item as PendingMessage, onRetry: () => _realtime.retry(item)),
                          ]);
                        },
                      )),
        SafeArea(top: false, child: _ended ? _endedBar() : _inputBar(name)),
      ]),
    );
  }

  Widget _inputBar(String name) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _onTyping,
            decoration: InputDecoration(hintText: 'Message $name', filled: true, fillColor: const Color(0xFFF1F3F6), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
          )),
          const SizedBox(width: 6),
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
        ]),
      );

  Widget _endedBar() => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Text(_isTrial ? 'The free trial has ended' : _timed ? 'Chat time is over' : 'Chat ended', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      );
}

class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, required this.name, this.photoUrl, this.online = false, this.radius = 18});
  final String name;
  final String? photoUrl;
  final bool online;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final url = ApiConfig.mediaUrl(photoUrl);
    return Stack(children: [
      // Initials show until (and unless) the client's photo loads.
      CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.infoBg,
        foregroundImage: url != null ? NetworkImage(url) : null,
        onForegroundImageError: url != null ? (_, __) {} : null,
        child: Text(initial, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: radius * .75)),
      ),
      if (online)
        Positioned(right: 0, bottom: 0, child: Container(width: radius * .55, height: radius * .55, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
    ]);
  }
}

/// Running chat time for normal (non-trial) chats, counting up from the start.
class _ChatClock extends StatelessWidget {
  const _ChatClock({required this.seconds});
  final int seconds;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFE8F5E9),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('Chat time · ${elapsedLabel(seconds < 0 ? 0 : seconds)}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
      );
}

class _TrialBar extends StatelessWidget {
  const _TrialBar({required this.seconds, this.trial = false});
  final int seconds;
  final bool trial;
  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 15;
    return Container(
      width: double.infinity,
      color: urgent ? const Color(0xFFFDECEA) : AppColors.infoBg,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(trial ? 'Free trial · ${countdown(seconds)} left' : 'Time left · ${countdown(seconds)}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: urgent ? AppColors.danger : AppColors.primary)),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE3E7EE), borderRadius: BorderRadius.circular(10)), child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      );
}

class _CallEntry extends StatelessWidget {
  const _CallEntry({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final missed = message.callStatus != 'ended';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(missed ? Icons.phone_missed : Icons.call, size: 16, color: missed ? AppColors.danger : AppColors.success),
          const SizedBox(width: 6),
          Text(message.text, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Text(clockTime(message.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

/// Right = me (lawyer), left = client. Ticks: clock = waiting to send,
/// ✓ sent, ✓✓ delivered, blue ✓✓ read, red ! failed (tap to retry).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.time, required this.mine, this.status, this.error, this.onRetry});
  factory _Bubble.fromMessage(ChatMessage m) => _Bubble(text: m.text, time: m.createdAt, mine: m.senderRole == 'lawyer', status: m.status);
  factory _Bubble.fromPending(PendingMessage p, {VoidCallback? onRetry}) => _Bubble(text: p.text, time: p.createdAt, mine: true, status: p.failed ? MessageStatus.failed : MessageStatus.pending, error: p.error, onRetry: onRetry);

  final String text;
  final DateTime time;
  final bool mine;
  final MessageStatus? status;
  final String? error;
  final VoidCallback? onRetry;

  Widget _tick() => switch (status) {
        MessageStatus.pending => const Icon(Icons.schedule, size: 14, color: Colors.white70),
        MessageStatus.failed => const Icon(Icons.error_outline, size: 14, color: Color(0xFFFF8A80)),
        MessageStatus.sent => const Icon(Icons.done, size: 15, color: Colors.white70),
        MessageStatus.delivered => const Icon(Icons.done_all, size: 15, color: Colors.white70),
        MessageStatus.read => const Icon(Icons.done_all, size: 15, color: Color(0xFF53BDEB)),
        null => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      decoration: BoxDecoration(color: mine ? AppColors.primary : Colors.white, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Align(alignment: Alignment.centerLeft, widthFactor: 1, child: Text(text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary, fontSize: 15))),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(clockTime(time), style: TextStyle(fontSize: 11, color: mine ? Colors.white60 : Colors.black45)),
          if (mine) ...[const SizedBox(width: 4), _tick()],
        ]),
        if (error != null) Text(error!, style: const TextStyle(fontSize: 11, color: Color(0xFFFF8A80))),
      ]),
    );
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: status == MessageStatus.failed ? GestureDetector(onTap: onRetry, child: bubble) : bubble);
  }
}
