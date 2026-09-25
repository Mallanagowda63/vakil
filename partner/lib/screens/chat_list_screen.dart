import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../utils/chat_format.dart';
import 'active_consultation_chat_screen.dart';

/// All chats: ongoing first, then by latest activity, with the last message,
/// its time and an unread badge. Refreshes on chat events and on resume.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  static const _refreshEvents = {'connect', 'new_message', 'message_read', 'chat_ended', 'status_updated', 'user_online', 'user_offline'};
  final _service = PartnerConsultationService();
  StreamSubscription<SocketEvent>? _events;
  Timer? _debounce;
  List<ChatSummary>? _chats;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = RealtimeService.instance.events.stream.where((e) => _refreshEvents.contains(e.name)).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _load);
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      final chats = await _service.chats(token);
      if (mounted) setState(() { _chats = chats; _error = null; });
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(ChatSummary chat) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActiveConsultationChatScreen(requestId: chat.requestId, title: chat.other.name)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final chats = _chats;
    return Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Chats', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))),
      Expanded(child: RefreshIndicator(
        onRefresh: _load,
        child: _error != null && chats == null
            ? ListView(children: [const SizedBox(height: 120), Center(child: Text(_error!)), Center(child: TextButton(onPressed: _load, child: const Text('Try again')))])
            : chats == null
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No chats yet. Accepted requests appear here.', style: TextStyle(color: AppColors.textSecondary)))])
                    : ListView.separated(
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                        itemBuilder: (_, i) => _ChatRow(chat: chats[i], onTap: () => _open(chats[i])),
                      ),
      )),
    ]);
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.onTap});
  final ChatSummary chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = chat.lastMessage;
    final mine = last?.senderRole == 'lawyer';
    final preview = last == null ? (chat.isOngoing ? 'Chat started' : 'Chat ended') : last.isCall ? '📞 ${last.text}' : last.text;
    final time = chat.lastActivityAt;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClientAvatar(name: chat.other.name, photoUrl: chat.other.photoUrl, online: chat.isOngoing && chat.other.online, radius: 24),
      title: Row(children: [
        Expanded(child: Text(chat.other.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (time != null) Text(listTime(time), style: TextStyle(fontSize: 12, color: chat.unread > 0 ? AppColors.success : AppColors.textSecondary)),
      ]),
      subtitle: Row(children: [
        if (mine && last != null && !last.isCall) ...[
          Icon(last.status == MessageStatus.sent ? Icons.done : Icons.done_all, size: 15, color: last.status == MessageStatus.read ? const Color(0xFF53BDEB) : AppColors.textSecondary),
          const SizedBox(width: 3),
        ],
        Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (chat.isOngoing) Padding(padding: const EdgeInsets.only(left: 6), child: Text(chat.isTrial ? 'FREE TRIAL' : 'ONGOING', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
        if (chat.unread > 0)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
            child: Text('${chat.unread}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}
