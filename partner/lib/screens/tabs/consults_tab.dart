import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_models.dart';
import '../../models/dashboard_data.dart';
import '../../models/session_book.dart';
import '../../models/wallet_data.dart';
import '../../services/consultation_service.dart';
import '../../services/partner_auth_service.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/chat_format.dart';
import '../../widgets/law_points.dart';
import '../../widgets/lt_ui.dart';
import '../active_consultation_chat_screen.dart';
import 'partner_nav.dart';

/// Consultations: incoming requests, active and finished consultations, the
/// chat list and the lawyer's own Session book.
class ConsultsTab extends StatefulWidget {
  const ConsultsTab({super.key});
  @override
  State<ConsultsTab> createState() => _ConsultsTabState();
}

class _ConsultsTabState extends State<ConsultsTab> {
  final _service = PartnerConsultationService();
  final _query = TextEditingController();
  StreamSubscription<SocketEvent>? _events;
  Timer? _debounce, _tick;
  List<ChatSummary>? _chats;
  List<Map<String, dynamic>>? _declined;
  bool _searchOpen = false;
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _events = RealtimeService.instance.events.stream.listen((e) {
      if (const {'new_message', 'status_updated', 'chat_ended', 'connect', 'message_read'}.contains(e.name)) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), _load);
      }
    });
    // Countdowns on incoming requests and active consultations.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    PartnerNav.consultsSegment.addListener(_rebuild);
    PartnerNav.consultsFilter.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _events?.cancel();
    _debounce?.cancel();
    _tick?.cancel();
    _query.dispose();
    PartnerNav.consultsSegment.removeListener(_rebuild);
    PartnerNav.consultsFilter.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      final results = await Future.wait([_service.chats(token), _service.history(token, 'REJECTED')]);
      if (!mounted) return;
      setState(() { _chats = results[0] as List<ChatSummary>; _declined = results[1] as List<Map<String, dynamic>>; });
    } catch (_) {
      if (mounted) setState(() { _chats ??= const []; _declined ??= const []; });
    }
  }

  String get _q => _query.text.trim().toLowerCase();
  bool _matches(String category, String text) => (_category == 'all' || categoryOf(category) == _category) && (_q.isEmpty || '$text $category'.toLowerCase().contains(_q));

  Future<void> _openChat(String requestId, String name) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActiveConsultationChatScreen(requestId: requestId, title: name)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final seg = PartnerNav.consultsSegment.value;
    return RefreshIndicator(
      color: c.brand,
      onRefresh: () async { await Future.wait([_load(), context.read<DashboardController>().refreshRequests()]); },
      child: ListView(padding: const EdgeInsets.fromLTRB(0, 14, 0, 120), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Expanded(child: Text('Consultations', style: sora(28, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.5))),
            GestureDetector(
              onTap: () => setState(() { _searchOpen = !_searchOpen; if (!_searchOpen) _query.clear(); }),
              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)), child: Icon(_searchOpen ? Icons.close : Icons.search, size: 20, color: c.ink)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (_searchOpen) Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search client, case or law…',
              prefixIcon: Icon(Icons.search, color: c.muted),
              filled: true, fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.brand)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Segmented<String>(items: const [('consults', 'Consults'), ('chats', 'Chats'), ('sessions', 'Session Book')], selected: seg, onSelected: (v) => PartnerNav.consultsSegment.value = v),
        ),
        const SizedBox(height: 14),
        if (seg != 'chats') ...[
          PillBar<String>(
            dark: false,
            items: [(value: 'all', label: 'All', sub: null, count: null), for (final cat in lawCategories) (value: cat.id, label: cat.label, sub: cat.acts, count: null)],
            selected: _category,
            onSelected: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: seg == 'consults' ? 0 : 18),
          child: switch (seg) { 'chats' => _chatList(c), 'sessions' => _SessionBookView(matches: _matches), _ => _consults(c) },
        ),
      ]),
    );
  }

  // ------------------------------------------------------------- consults

  Widget _consults(LT c) {
    final dash = context.watch<DashboardController>();
    final keep = 1 - (context.watch<WalletController>().commissionPercent > 0 ? context.watch<WalletController>().commissionPercent : 20) / 100;
    final incoming = dash.requests.where((r) => _matches(r.category, '${r.clientName} ${r.problemSummary}')).toList();
    final chats = _chats ?? const <ChatSummary>[];
    final active = chats.where((x) => x.isOngoing && _matches(x.category, x.other.name)).toList();
    final completed = chats.where((x) => x.status == 'COMPLETED' && _matches(x.category, x.other.name)).toList();
    final declined = (_declined ?? const []).where((r) => _matches(r['category']?.toString() ?? '', r['userName']?.toString() ?? '')).toList();
    final filter = PartnerNav.consultsFilter.value;
    final filtering = _category != 'all' || _q.isNotEmpty;

    Widget body;
    if (_chats == null && filter != 'incoming') {
      body = const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Loading…')));
    } else {
      switch (filter) {
        case 'active':
          body = active.isEmpty ? EmptyCard(icon: Icons.work_outline, title: filtering ? 'Nothing matches' : 'Nothing in progress', text: filtering ? 'Try another category or search.' : 'Accepted consultations appear here until they end.')
              : Column(children: [for (final x in active) Padding(padding: const EdgeInsets.only(bottom: 14), child: _activeCard(c, x))]);
        case 'completed':
          body = completed.isEmpty ? EmptyCard(icon: Icons.work_outline, title: filtering ? 'Nothing matches' : 'No completed consults yet')
              : LtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
                  for (var i = 0; i < completed.length; i++)
                    LtRow(
                      first: i == 0,
                      leading: Initials(completed[i].other.name),
                      title: completed[i].other.name,
                      subtitle: '${completed[i].category} · ${completed[i].isCall ? 'Voice' : 'Chat'}',
                      onTap: () => _openChat(completed[i].requestId, completed[i].other.name),
                      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(completed[i].isTrial && completed[i].totalAmount == 0 ? 'Free trial' : '+${inr(completed[i].totalAmount * keep)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: completed[i].totalAmount > 0 ? c.good : c.muted)),
                        Text(completed[i].lastActivityAt == null ? '' : dayLabel(completed[i].lastActivityAt!), style: TextStyle(fontSize: 12, color: c.muted)),
                      ]),
                    ),
                ]));
        case 'declined':
          body = declined.isEmpty ? EmptyCard(icon: Icons.work_outline, title: filtering ? 'Nothing matches' : 'Nothing declined')
              : LtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
                  for (var i = 0; i < declined.length; i++)
                    LtRow(
                      first: i == 0,
                      leading: Initials(declined[i]['userName']?.toString() ?? 'Client'),
                      title: declined[i]['userName']?.toString() ?? 'Client',
                      subtitle: declined[i]['category']?.toString() ?? '',
                      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const StateChip('Declined', tone: ChipTone.bad),
                        const SizedBox(height: 3),
                        Text(_date(declined[i]['rejectedAt'] ?? declined[i]['updatedAt']), style: TextStyle(fontSize: 11, color: c.muted)),
                      ]),
                    ),
                ]));
        default:
          body = incoming.isEmpty ? EmptyCard(icon: Icons.work_outline, title: filtering ? 'Nothing matches' : 'No incoming requests', text: filtering ? 'Try another category or search.' : dash.onlineStatus ? 'When clients pick you, their requests show up here.' : 'You are offline. Go online on Home to get requests.')
              : Column(children: [for (final r in incoming) Padding(padding: const EdgeInsets.only(bottom: 14), child: _incomingCard(c, r))]);
      }
    }

    return Column(children: [
      PillBar<String>(
        items: [
          (value: 'incoming', label: 'Incoming', sub: null, count: incoming.length),
          (value: 'active', label: 'Active', sub: null, count: active.length),
          (value: 'completed', label: 'Completed', sub: null, count: completed.length),
          (value: 'declined', label: 'Declined', sub: null, count: declined.length),
        ],
        selected: filter,
        onSelected: (v) => PartnerNav.consultsFilter.value = v,
      ),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: body),
    ]);
  }

  static String _date(Object? iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    return d == null ? '' : dayLabel(d);
  }

  Widget _mode(LT c, bool voice) => StateChip(voice ? 'Voice' : 'Chat', tone: ChipTone.brand, icon: voice ? Icons.mic_none_rounded : Icons.chat_bubble_outline);

  Widget _fact(LT c, IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: c.muted), const SizedBox(width: 5), Text(text, style: TextStyle(fontSize: 12, color: c.muted))]);

  Widget _incomingCard(LT c, ConsultationRequest r) {
    final voice = r.type == ConsultationType.voice;
    final left = r.secondsLeft;
    return LtCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Initials(r.clientName),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.clientName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: c.ink)),
          Text(r.category, style: TextStyle(fontSize: 12, color: c.muted)),
        ])),
        _mode(c, voice),
      ]),
      if (r.problemSummary.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(r.problemSummary, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.ink))) else const SizedBox(height: 12),
      Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c.bad, shape: BoxShape.circle)), const SizedBox(width: 6), Text('Expires in 0:${left.toString().padLeft(2, '0')}', style: mono(12.5, color: c.bad))]),
        _fact(c, Icons.timer_outlined, r.isTrial ? 'Free 1-min trial' : r.maxMinutes > 0 ? '${r.maxMinutes} min prepaid' : 'Per minute'),
        if (!r.isTrial) _fact(c, Icons.currency_rupee, '${r.pricePerMinute}/min'),
        LawPointsButton(categoryOf(r.category)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(flex: 10, child: LtButton('Decline', kind: BtnKind.ghost, icon: Icons.close, onTap: () async {
          try { await context.read<DashboardController>().rejectRequest(r.id); if (mounted) { toast(context, "Declined ${r.clientName}'s request"); _load(); } }
          catch (e) { if (mounted) toast(context, e.toString()); }
        })),
        const SizedBox(width: 8),
        Expanded(flex: 16, child: LtButton(voice ? 'Accept voice' : 'Accept chat', icon: Icons.check, onTap: () async {
          bool ok;
          try { ok = await context.read<DashboardController>().acceptRequest(r.id); } catch (e) { if (mounted) toast(context, e.toString()); return; }
          if (!mounted) return;
          if (!ok) { toast(context, 'This request is no longer available'); return; }
          PartnerNav.consultsFilter.value = 'active';
          _openChat(r.id, r.clientName);
        })),
      ]),
    ]));
  }

  Widget _activeCard(LT c, ChatSummary x) {
    final left = x.remainingSeconds;
    final label = left != null ? 'Time left ${countdown(left)}' : x.elapsedSeconds != null ? '${elapsedLabel(x.elapsedSeconds!)} elapsed' : 'In progress';
    final last = x.lastMessage;
    return LtCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Initials(x.other.name, highlight: true),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(x.other.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: c.ink)),
          Text(x.category, style: TextStyle(fontSize: 12, color: c.muted)),
        ])),
        _mode(c, x.isCall),
      ]),
      if (last != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_preview(last), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.ink))) else const SizedBox(height: 12),
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c.bad, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: mono(13, color: c.bad)),
        const Spacer(),
        LawPointsButton(categoryOf(x.category)),
      ]),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: LtButton(x.isCall ? 'Open voice consultation' : 'Open chat', icon: x.isCall ? Icons.mic_none_rounded : Icons.chat_bubble_outline, onTap: () => _openChat(x.requestId, x.other.name))),
    ]));
  }

  static String _preview(ChatMessage m) => m.type == 'image' ? '📷 Photo' : m.type == 'audio' ? '🎤 Voice message' : m.type == 'file' ? '📎 ${m.text}' : m.text;

  // ------------------------------------------------------------- chats

  Widget _chatList(LT c) {
    final chats = (_chats ?? const <ChatSummary>[]).where((x) => _q.isEmpty || '${x.other.name} ${x.lastMessage?.text ?? ''}'.toLowerCase().contains(_q)).toList();
    if (_chats == null) return const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Loading…')));
    if (chats.isEmpty) return EmptyCard(icon: Icons.chat_bubble_outline, title: _q.isEmpty ? 'No chats yet' : 'No chats found', text: _q.isEmpty ? 'Accepted requests appear here.' : 'Try another name.');
    return LtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
      for (var i = 0; i < chats.length; i++)
        LtRow(
          first: i == 0,
          leading: Initials(chats[i].other.name, highlight: chats[i].isOngoing),
          title: chats[i].other.name,
          subtitle: chats[i].lastMessage == null ? (chats[i].isOngoing ? 'Chat started' : 'Chat ended') : _preview(chats[i].lastMessage!),
          onTap: () => _openChat(chats[i].requestId, chats[i].other.name),
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(chats[i].lastActivityAt == null ? '' : _when(chats[i].lastActivityAt!), style: TextStyle(fontSize: 12, color: c.muted)),
            if (chats[i].unread > 0) Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(99)),
              child: Text('${chats[i].unread}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.brandInk)),
            ),
          ]),
        ),
    ]));
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return clockTime(t);
    return dayLabel(t);
  }
}

// ------------------------------------------------------------- session book

class _SessionBookView extends StatefulWidget {
  const _SessionBookView({required this.matches});
  final bool Function(String category, String text) matches;
  @override
  State<_SessionBookView> createState() => _SessionBookViewState();
}

class _SessionBookViewState extends State<_SessionBookView> {
  bool _adding = false;
  final _name = TextEditingController();
  String _cat = lawCategories.first.id, _mode = 'Chat';
  DateTime _at = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 17, minute: 0, second: 0, millisecond: 0, microsecond: 0);

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) { toast(context, "Enter the client's name to book"); return; }
    await SessionBook.instance.add(BookedSession(id: '${DateTime.now().microsecondsSinceEpoch}', client: _name.text.trim(), category: _cat, mode: _mode, at: _at));
    _name.clear();
    if (mounted) { setState(() => _adding = false); toast(context, 'Session booked'); }
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return ListenableBuilder(listenable: SessionBook.instance, builder: (context, _) {
      final list = SessionBook.instance.upcoming.where((s) => widget.matches(s.category, '${s.client} ${s.mode}')).toList();
      final days = <String, List<BookedSession>>{};
      for (final s in list) { days.putIfAbsent(_day(s.at), () => []).add(s); }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_adding) SizedBox(width: double.infinity, child: LtButton('+ Add session', onTap: () => setState(() => _adding = true))) else _form(c),
        if (list.isEmpty) ...[const SizedBox(height: 12), const EmptyCard(icon: Icons.event_note_outlined, title: 'No sessions', text: 'Add the sessions you plan with clients. They are kept on this phone.')],
        for (final entry in days.entries) ...[
          SecHead(entry.key, trailing: Text('${entry.value.length} booked', style: TextStyle(fontSize: 12, color: c.muted))),
          LtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
            for (var i = 0; i < entry.value.length; i++) _sessionRow(c, entry.value[i], i == 0),
          ])),
        ],
      ]);
    });
  }

  Widget _sessionRow(LT c, BookedSession s, bool first) {
    final h = s.at.hour % 12 == 0 ? 12 : s.at.hour % 12;
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 12), child: Icon(Icons.delete_outline, color: c.bad)),
      onDismissed: (_) { SessionBook.instance.remove(s.id); toast(context, 'Session removed'); },
      child: LtRow(
        first: first,
        leading: Container(
          width: 52, padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(11)),
          child: Column(children: [
            Text('$h:${s.at.minute.toString().padLeft(2, '0')}', style: sora(14, color: c.ink)),
            Text(s.at.hour >= 12 ? 'PM' : 'AM', style: TextStyle(fontSize: 10, color: c.muted, letterSpacing: 0.8)),
          ]),
        ),
        title: s.client,
        subtitle: '${lawLabel(s.category)} · ${s.mode} · ${s.minutes} min',
        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          s.confirmed ? const StateChip('Confirmed') : StateChip('Confirm', tone: ChipTone.wait, onTap: () => SessionBook.instance.confirm(s.id)),
          const SizedBox(height: 6),
          LawPointsButton(s.category),
        ]),
      ),
    );
  }

  Widget _form(LT c) {
    InputDecoration deco(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: c.surface2, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)));
    Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)));
    final h = _at.hour % 12 == 0 ? 12 : _at.hour % 12;
    return LtCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('New session', style: sora(16, color: c.ink))), IconButton(onPressed: () => setState(() => _adding = false), icon: Icon(Icons.close, color: c.ink))]),
      label('Client name'),
      TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: deco('e.g. Rahul Desai')),
      label('Category'),
      DropdownButtonFormField<String>(initialValue: _cat, decoration: deco(''), items: [for (final cat in lawCategories) DropdownMenuItem(value: cat.id, child: Text('${cat.label} · ${cat.acts}'))], onChanged: (v) => setState(() => _cat = v ?? _cat)),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('Date'),
          OutlinedButton(onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
          }, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)), child: Text(_day(_at))),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('Time'),
          OutlinedButton(onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
            if (t != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
          }, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)), child: Text('$h:${_at.minute.toString().padLeft(2, '0')} ${_at.hour >= 12 ? 'PM' : 'AM'}')),
        ])),
      ]),
      label('Mode'),
      Segmented<String>(items: const [('Chat', 'Chat'), ('Voice', 'Voice'), ('In person', 'In person')], selected: _mode, onSelected: (v) => setState(() => _mode = v)),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: LtButton('Book session', icon: Icons.check, onTap: _save)),
    ]));
  }
}
