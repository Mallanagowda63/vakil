import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/consultation_service.dart';
import '../services/realtime_service.dart';
import '../state/free_trial_state.dart';
import '../state/wallet_state.dart';
import '../utils/currency.dart';
import '../widgets/add_time_sheet.dart';
import '../widgets/wallet_widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/chat_format.dart';
import 'lawyers_screen.dart';
import 'rate_lawyer_screen.dart';

/// One chat with a lawyer. Messages go through RealtimeService (queued while
/// offline); the REST API reloads the truth on open, reconnect and resume.
/// No sounds play here: the User App only rings for incoming calls.
class LiveConsultationChatScreen extends StatefulWidget {
  const LiveConsultationChatScreen({super.key, required this.requestId, required this.title, this.photoUrl, this.startCall = false});
  final String requestId;
  final String title;
  final String? photoUrl;
  /// Opened from a call request: start the voice call as soon as the chat loads.
  final bool startCall;
  @override
  State<LiveConsultationChatScreen> createState() => _State();
}

class _State extends State<LiveConsultationChatScreen> with WidgetsBindingObserver {
  final _service = ConsultationService();
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
  bool _lawyerTyping = false;
  bool _iAmTyping = false;
  bool _otherOnline = false;
  DateTime? _lastSeen;
  String _status = 'ONGOING';
  bool _isTrial = false;
  int? _rating;
  // Local deadline from the server's remainingSeconds, so the phone clock doesn't matter.
  DateTime? _endsAt;
  // When the chat started, from the server's elapsedSeconds (phone clock doesn't matter).
  DateTime? _startedAt;
  // True once this chat showed a countdown, so its end reads "Chat time is over".
  bool _timed = false;
  bool _foreground = true;
  // Paid chat (after the free trial): price, minutes charged and their total, from the server.
  double? _rate;
  int _billedMinutes = 0;
  double _totalAmount = 0;
  String? _endReason;

  bool _callStarted = false;
  bool get _paid => !_isTrial && (_rate ?? 0) > 0;

  String get _id => widget.requestId;
  int? get _remaining { final s = _endsAt?.difference(DateTime.now()).inSeconds; return s == null ? null : (s < 0 ? 0 : s); }
  bool get _ended => _status != 'ONGOING' || _remaining == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = _realtime.events.stream.listen(_onEvent);
    _outbox = _realtime.outboxChanged.stream.where((id) => id == _id).listen((_) { if (mounted) setState(() {}); });
    _scroll.addListener(_maybeLoadOlder);
    _load();
  }

  @override
  void dispose() {
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
    try {
      final chat = await _service.chat(_id);
      final page = await _service.messages(_id);
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
      if (widget.startCall && !_callStarted && !_ended) { _callStarted = true; _startCall(); }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  /// After a reconnect or coming back to the foreground: refresh status,
  /// the trial clock and presence, and fetch messages missed meanwhile.
  Future<void> _resync() async {
    if (_loading) return;
    try {
      final chat = await _service.chat(_id);
      final last = _messages.isEmpty ? null : _messages.last.id;
      final missed = last == null ? await _service.messages(_id) : await _service.messages(_id, after: last);
      if (!mounted) return;
      setState(() { _applyChat(chat); for (final m in missed.items) { _insert(m); } });
      _realtime.emit('join_chat', {'requestId': _id});
      _markRead();
    } catch (_) {}
  }

  void _applyChat(ChatSummary chat) {
    // Only an end seen while this screen is open opens the rating screen.
    final wasOngoing = _chat != null && !_ended;
    _chat = chat;
    _status = chat.status;
    _isTrial = chat.isTrial;
    _rating = chat.rating;
    _rate = chat.ratePerMinute;
    _billedMinutes = chat.billedMinutes;
    _totalAmount = chat.totalAmount;
    _endReason = chat.endReason;
    _otherOnline = chat.other.online;
    _lastSeen = chat.other.lastSeenAt;
    _endsAt = chat.isOngoing && chat.remainingSeconds != null ? DateTime.now().add(Duration(seconds: chat.remainingSeconds!)) : null;
    if (chat.remainingSeconds != null) _timed = true;
    _startedAt = chat.isOngoing && chat.elapsedSeconds != null ? DateTime.now().subtract(Duration(seconds: chat.elapsedSeconds!)) : null;
    _ticker?.cancel();
    if (chat.isOngoing) _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); if (_ended) _onEnded(); });
    if (wasOngoing && _ended && _chat != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onEnded());
  }

  bool _endHandled = false;
  void _onEnded() {
    _ticker?.cancel();
    if (_isTrial) { AuthService.instance.trialUsed = true; FreeTrialState.used = true; }
    if (_endHandled || !mounted || _loading) return;
    _endHandled = true;
    if (_endReason == 'balance_over') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat ended: your wallet balance ran out. Total ${formatCurrency(_totalAmount)}.'), action: SnackBarAction(label: 'Recharge', onPressed: () => openWallet(context))));
    }
    if (_rating == null) _openRating();
  }

  void _insert(ChatMessage message) {
    if (!_ids.add(message.id)) return;
    _messages.add(message);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _markRead() {
    final unread = _messages.where((m) => m.senderRole == 'lawyer' && m.status != MessageStatus.read).toList();
    if (!_foreground || unread.isEmpty) return;
    _realtime.emit('message_read', {'requestId': _id});
    for (final m in unread) {
      m.status = MessageStatus.read;
    }
  }

  void _onEvent(SocketEvent event) {
    final data = event.data;
    if (event.name == 'connect') { _resync(); return; }
    // Presence events carry the lawyer's id, not the request id.
    if ((event.name == 'user_online' || event.name == 'user_offline') && data['id']?.toString() == _chat?.other.id) {
      if (mounted) setState(() { _otherOnline = event.name == 'user_online'; _lastSeen = DateTime.tryParse(data['lastSeenAt']?.toString() ?? '')?.toLocal() ?? _lastSeen; });
      return;
    }
    final forThisChat = data['requestId']?.toString() == _id || data['id']?.toString() == _id;
    if (!forThisChat || !mounted) return;
    switch (event.name) {
      case 'new_message':
        final message = ChatMessage.fromJson(data);
        setState(() { _insert(message); if (message.senderRole == 'lawyer') _lawyerTyping = false; });
        if (message.senderRole == 'lawyer') _markRead();
        _scrollToBottom();
      case 'message_delivered' || 'message_read':
        final ids = (data['messageIds'] as List? ?? const []).map((e) => e.toString()).toSet();
        final status = event.name == 'message_read' ? MessageStatus.read : MessageStatus.delivered;
        setState(() { for (final m in _messages) { if (m.senderRole == 'user' && ids.contains(m.id) && m.status.index < status.index) m.status = status; } });
      case 'typing_start' || 'typing_stop':
        if (data['role'] != 'lawyer') return;
        setState(() => _lawyerTyping = event.name == 'typing_start');
        _typingClear?.cancel();
        if (_lawyerTyping) _typingClear = Timer(const Duration(seconds: 6), () { if (mounted) setState(() => _lawyerTyping = false); });
      case 'chat_billing':
        setState(() {
          _billedMinutes = (data['billedMinutes'] as num?)?.toInt() ?? _billedMinutes;
          _totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? _totalAmount;
          _rate = (data['ratePerMinute'] as num?)?.toDouble() ?? _rate;
        });
      case 'chat_extended':
        // Time was added (here, on the call screen or another phone).
        setState(() {
          final seconds = (data['remainingSeconds'] as num?)?.toInt();
          if (seconds != null) _endsAt = DateTime.now().add(Duration(seconds: seconds));
          _billedMinutes = (data['billedMinutes'] as num?)?.toInt() ?? _billedMinutes;
          _totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? _totalAmount;
          _rate = (data['ratePerMinute'] as num?)?.toDouble() ?? _rate;
        });
      case 'low_balance':
        // The banner shows while the balance is below one minute (see build).
        setState(() {});
      case 'chat_ended' || 'request_completed':
        setState(() {
          _status = 'COMPLETED'; _endsAt = null;
          _endReason = data['reason']?.toString() ?? _endReason;
          _totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? _totalAmount;
        });
        _onEnded();
    }
  }

  Future<void> _maybeLoadOlder() async {
    if (!_hasMore || _loadingOlder || _messages.isEmpty || _scroll.position.pixels < _scroll.position.maxScrollExtent - 200) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _service.messages(_id, before: _messages.first.id);
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

  Future<void> _startCall() async {
    final error = await CallService.instance.startCall(requestId: _id, otherName: _chat?.other.name ?? widget.title, otherPhotoUrl: _chat?.other.photoUrl ?? widget.photoUrl);
    if (error == null || !mounted) return;
    // 402 from the server: the wallet can't cover another minute.
    if (error == 'Insufficient balance') { openWallet(context, message: 'Add money to call this lawyer'); return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _addTime() async {
    final seconds = await showAddTimeSheet(context, requestId: _id, rate: _rate);
    if (seconds == null || !mounted) return;
    setState(() => _endsAt = DateTime.now().add(Duration(seconds: seconds)));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time added')));
  }

  Future<void> _confirmEnd() async {
    final end = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('End chat?'),
      content: Text('You will not be able to send more messages to ${_chat?.other.name ?? widget.title}.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Chat'))],
    ));
    if (end != true) return;
    try {
      await _service.endChat(_id);
    } on ApiException catch (e) {
      // 409: already ended by the lawyer or the timer; the refresh shows it.
      if (e.statusCode != 409 && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    await _resync();
    if (mounted && _ended) { setState(() {}); _onEnded(); }
  }

  Future<void> _openRating() async {
    final rated = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => RateLawyerScreen(requestId: _id, lawyerName: _chat?.other.name ?? widget.title, photoUrl: _chat?.other.photoUrl ?? widget.photoUrl)));
    if (rated != null && mounted) setState(() => _rating = rated);
  }

  String get _subtitle {
    if (_ended) return 'Chat ended';
    if (_lawyerTyping) return 'typing...';
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          LawyerAvatar(name: name, photoUrl: _chat?.other.photoUrl ?? widget.photoUrl, online: _otherOnline && !_ended, radius: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppText.h3(AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_subtitle, style: AppText.caption(_lawyerTyping && !_ended ? AppColors.greenAccent : AppColors.textGray)),
            if (_paid) ValueListenableBuilder<double>(
              valueListenable: WalletState.balanceListenable,
              builder: (_, balance, _) => Text('${formatCurrency(_totalAmount)} spent · Balance ${formatCurrency(balance)}', style: AppText.caption(balance < (_rate ?? 0) && !_ended ? AppColors.redAccent : AppColors.blueAccent).copyWith(fontWeight: FontWeight.w600)),
            ),
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
          builder: (_, online, _) => online ? const SizedBox.shrink() : Container(width: double.infinity, color: AppColors.amberSoft, padding: const EdgeInsets.symmetric(vertical: 4), child: Text('Connecting…', textAlign: TextAlign.center, style: AppText.caption(AppColors.textDark))),
        ),
        // Countdown to the chat's end (2:00 → 0:00, trial 1:00 → 0:00); older chats without a limit count up.
        if (!_ended && _remaining != null) ...[
          _TrialBar(seconds: _remaining!, trial: _isTrial, onAddTime: _loading ? null : _addTime),
          // The last minute: ask to add time before the chat and any call end.
          if (_remaining! <= 60) _TimeWarningBanner(trial: _isTrial, onAddTime: _addTime),
        ]
        else if (!_ended && _paid) _PaidBar(seconds: _startedAt == null ? null : DateTime.now().difference(_startedAt!).inSeconds, rate: _rate!, minutes: _billedMinutes, total: _totalAmount)
        else if (!_ended && _startedAt != null) _ChatClock(seconds: DateTime.now().difference(_startedAt!).inSeconds),
        // Per-minute chats (older app versions): less than one more minute left in the wallet.
        if (!_ended && _paid && _remaining == null) ValueListenableBuilder<double>(
          valueListenable: WalletState.balanceListenable,
          builder: (_, balance, _) => balance >= _rate! ? const SizedBox.shrink() : _LowBalanceBanner(onRecharge: () => openWallet(context)),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Try again'))]))
                : items.isEmpty
                    ? Center(child: Text(_ended ? 'This chat has ended.' : 'Your lawyer accepted. Say hello!', style: AppText.body(AppColors.textGray)))
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
        SafeArea(top: false, child: _ended ? _endedBar(name) : _inputBar()),
      ]),
    );
  }

  Widget _inputBar() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _onTyping,
            decoration: InputDecoration(hintText: 'Type a message', filled: true, fillColor: const Color(0xFFF1F3F6), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
          )),
          const SizedBox(width: 6),
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
        ]),
      );

  Widget _endedBar(String name) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_isTrial ? 'Your free trial has ended' : _timed ? 'Chat time is over' : 'Chat ended', style: AppText.bodyMedium(AppColors.textDark)),
          if (_rating == null) TextButton(onPressed: _openRating, child: Text('Rate $name')),
        ]),
      );
}

/// Running chat time for normal (non-trial) chats, counting up from the start.
/// Paid chat: time, price, minutes charged and the running cost.
class _PaidBar extends StatelessWidget {
  const _PaidBar({required this.seconds, required this.rate, required this.minutes, required this.total});
  final int? seconds;
  final double rate;
  final int minutes;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.blueSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.timer_outlined, size: 15, color: AppColors.blueAccent),
        const SizedBox(width: 6),
        Text(seconds == null ? '--:--' : formatMinutesSeconds(seconds!), style: AppText.bodyMedium(AppColors.blueAccent)),
        const SizedBox(width: 10),
        Expanded(child: Text('${formatRate(rate)} · $minutes min charged', style: AppText.caption(AppColors.textGray), overflow: TextOverflow.ellipsis)),
        Text(formatCurrency(total), style: AppText.bodyMedium(AppColors.textDark).copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _LowBalanceBanner extends StatelessWidget {
  const _LowBalanceBanner({required this.onRecharge});
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.redSoft,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.redAccent),
        const SizedBox(width: 8),
        Expanded(child: Text('Low balance – the chat ends when it runs out.', style: AppText.caption(AppColors.redAccent).copyWith(fontWeight: FontWeight.w600))),
        TextButton(onPressed: onRecharge, child: const Text('Recharge')),
      ]),
    );
  }
}

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

/// Shown in the chat's last minute: add time or the chat (and call) ends.
class _TimeWarningBanner extends StatelessWidget {
  const _TimeWarningBanner({required this.trial, required this.onAddTime});
  final bool trial;
  final VoidCallback onAddTime;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.amberSoft,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(children: [
          const Icon(Icons.timer_off_outlined, size: 18, color: AppColors.redAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(trial ? 'Your free minute is ending. Buy time to keep chatting and calling.' : 'Less than 1 minute left. Add time to keep chatting and calling.', style: AppText.caption(AppColors.textDark).copyWith(fontWeight: FontWeight.w600))),
          FilledButton(onPressed: onAddTime, style: FilledButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(trial ? 'Buy time' : 'Add time')),
        ]),
      );
}

class _TrialBar extends StatelessWidget {
  const _TrialBar({required this.seconds, this.trial = false, this.onAddTime});
  final int seconds;
  final bool trial;
  final VoidCallback? onAddTime;
  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 15;
    final label = Text(trial ? 'Free trial · ${countdown(seconds)} left' : 'Time left · ${countdown(seconds)}', textAlign: TextAlign.center, style: AppText.bodyMedium(urgent ? AppColors.redAccent : AppColors.blueAccent));
    return Container(
      width: double.infinity,
      color: urgent ? AppColors.redSoft : AppColors.blueSoft,
      padding: EdgeInsets.fromLTRB(16, onAddTime == null ? 6 : 0, 4, onAddTime == null ? 6 : 0),
      child: onAddTime == null ? label : Row(children: [
        const Icon(Icons.timer_outlined, size: 15, color: AppColors.blueAccent),
        const SizedBox(width: 6),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: label)),
        TextButton.icon(onPressed: onAddTime, icon: const Icon(Icons.add, size: 16), label: Text(trial ? 'Buy time' : 'Add time')),
      ]),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE3E7EE), borderRadius: BorderRadius.circular(10)), child: Text(label, style: AppText.caption(AppColors.textGray))),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightStroke)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(missed ? Icons.phone_missed : Icons.call, size: 16, color: missed ? AppColors.redAccent : AppColors.greenAccent),
          const SizedBox(width: 6),
          Text(message.text, style: AppText.bodySmall(AppColors.textDark)),
          const SizedBox(width: 8),
          Text(clockTime(message.createdAt), style: AppText.caption(AppColors.textGray)),
        ]),
      ),
    );
  }
}

/// Right = me, left = lawyer. Ticks: clock = waiting to send, ✓ sent,
/// ✓✓ delivered, blue ✓✓ read, red ! failed (tap to retry).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.time, required this.mine, this.status, this.error, this.onRetry});
  factory _Bubble.fromMessage(ChatMessage m) => _Bubble(text: m.text, time: m.createdAt, mine: m.senderRole == 'user', status: m.status);
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
      decoration: BoxDecoration(color: mine ? const Color(0xFF171722) : Colors.white, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Align(alignment: Alignment.centerLeft, widthFactor: 1, child: Text(text, style: TextStyle(color: mine ? Colors.white : Colors.black87, fontSize: 15))),
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
