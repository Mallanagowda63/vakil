import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/consultation_service.dart';
import '../services/realtime_service.dart';
import '../state/home_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/wallet_widgets.dart';
import 'lawyer_profile_screen.dart';
import 'lawyer_search_screen.dart';
import 'request_consultation_screen.dart';

/// Lawyers from the server with name, photo, category, online status and a Chat button.
class LawyersScreen extends StatefulWidget {
  const LawyersScreen({super.key, this.excludeLawyerId, this.followHomeFilter = false});
  /// Hides one lawyer (used when suggesting others after a reject/expiry).
  final String? excludeLawyerId;
  /// The Lawyers tab: shows the speciality picked on the home screen.
  final bool followHomeFilter;
  @override
  State<LawyersScreen> createState() => _LawyersScreenState();
}

class _LawyersScreenState extends State<LawyersScreen> with WidgetsBindingObserver {
  final _service = ConsultationService();
  StreamSubscription<SocketEvent>? _events;
  Timer? _debounce;
  List<LawyerSummary>? _lawyers;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = RealtimeService.instance.events.stream.listen((event) {
      // A lawyer switched chat/call on or off: update that card in place, no reload.
      if (event.name == 'lawyer_status_changed') {
        final lawyers = _lawyers;
        if (lawyers == null || !lawyers.any((l) => l.id == event.data['id']?.toString())) { _reloadSoon(); return; }
        if (mounted) setState(() => _lawyers = applyLawyerStatus(lawyers, event.data));
      } else if (event.name == 'connect') {
        _reloadSoon();
      }
    });
    if (widget.followHomeFilter) HomeNav.speciality.addListener(_filterChanged);
    _load();
  }

  void _filterChanged() {
    if (!mounted) return;
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Speciality? get _filter => widget.followHomeFilter ? HomeNav.speciality.value : null;

  void _reloadSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.followHomeFilter) HomeNav.speciality.removeListener(_filterChanged);
    _scroll.dispose();
    _events?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final lawyers = sortLawyers(await _service.lawyers());
      if (mounted) setState(() { _lawyers = lawyers.where((l) => l.id != widget.excludeLawyerId).toList(); _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    // Online-first order (from the server and live updates) is kept inside the filter.
    final lawyers = filter == null ? _lawyers : _lawyers?.where(filter.matches).toList();
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(title: Text('Lawyers', style: AppText.h3(AppColors.textDark)), backgroundColor: Colors.white, surfaceTintColor: Colors.white, actions: [
        IconButton(tooltip: 'Search lawyers', icon: const Icon(Icons.search), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LawyerSearchScreen()))),
        const WalletButton(),
        const SizedBox(width: 12),
      ]),
      body: Column(children: [
        if (filter != null)
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(filter.name),
                avatar: const Icon(Icons.filter_list, size: 16),
                onDeleted: () => HomeNav.speciality.value = null,
                deleteButtonTooltipMessage: 'Show all lawyers',
                backgroundColor: AppColors.blueSoft,
                labelStyle: AppText.bodyMedium(AppColors.blueAccent),
              ),
            ),
          ),
        Expanded(child: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [const SizedBox(height: 120), Center(child: Text(_error!, style: AppText.body(AppColors.textGray))), Center(child: TextButton(onPressed: _load, child: const Text('Try again')))])
            : lawyers == null
                ? const Center(child: CircularProgressIndicator())
                : lawyers.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Center(child: Text(filter == null ? 'No lawyers available right now.' : 'No ${filter.name} lawyers yet.', style: AppText.body(AppColors.textGray))),
                        if (filter != null) Center(child: TextButton(onPressed: () => HomeNav.speciality.value = null, child: const Text('Show all lawyers'))),
                      ])
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: lawyers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => LawyerRow(lawyer: lawyers[i]),
                      ),
        )),
      ]),
    );
  }
}

class LawyerAvatar extends StatelessWidget {
  const LawyerAvatar({super.key, required this.name, this.photoUrl, this.online = false, this.radius = 24});
  final String name;
  final String? photoUrl;
  final bool online;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final url = ApiConfig.mediaUrl(photoUrl);
    return Stack(children: [
      // Initials show until (and unless) the photo loads.
      CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.blueSoft,
        foregroundImage: url != null ? NetworkImage(url) : null,
        onForegroundImageError: url != null ? (_, _) {} : null,
        child: Text(initial, style: AppText.h3(AppColors.blueAccent).copyWith(fontSize: radius * .75)),
      ),
      if (online)
        Positioned(right: 0, bottom: 0, child: Container(width: radius * .5, height: radius * .5, decoration: BoxDecoration(color: AppColors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
    ]);
  }
}

class LawyerRow extends StatelessWidget {
  const LawyerRow({super.key, required this.lawyer});
  final LawyerSummary lawyer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LawyerProfileScreen(lawyer: lawyer))),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightStroke)),
      child: Row(children: [
        LawyerAvatar(name: lawyer.name, photoUrl: lawyer.photoUrl, online: lawyer.online),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lawyer.name, style: AppText.h3(AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(lawyer.category, style: AppText.bodySmall(AppColors.textGray)),
            const SizedBox(height: 2),
            LawyerChannels(lawyer: lawyer),
            const SizedBox(height: 6),
            PriceTag(ratePerMinute: lawyer.ratePerMinute),
            if (lawyer.callRatePerMinute > 0) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Voice call ${formatRate(lawyer.callRatePerMinute)}', style: AppText.caption(AppColors.textGray))),
            if (lawyer.ratingAverage != null) Padding(padding: const EdgeInsets.only(top: 3), child: RatingLine(average: lawyer.ratingAverage!, count: lawyer.ratingCount)),
          ]),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          ChatCallButton(lawyer: lawyer),
          const SizedBox(height: 6),
          ChatCallButton(lawyer: lawyer, call: true),
        ]),
      ]),
    ),
    );
  }
}

/// Opens the request screen for a chat, or for a call ([call]): after the
/// lawyer accepts, the chat opens and the call starts.
void requestLawyer(BuildContext context, LawyerSummary lawyer, {bool call = false}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestConsultationScreen(
      lawyerId: lawyer.id, lawyerName: lawyer.name, category: lawyer.category, photoUrl: lawyer.photoUrl, ratePerMinute: lawyer.rateFor(call: call), consultationType: call ? 'call' : 'chat')));

/// "★ 4.8 (12)" — clients' average rating.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.average, required this.count, this.color});
  final double average;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 15, color: AppColors.starGold),
        const SizedBox(width: 3),
        Text('${average.toStringAsFixed(1)} ($count)', style: AppText.caption(color ?? AppColors.textDark).copyWith(fontWeight: FontWeight.w600)),
      ]);
}

/// Green "Online" dot plus what the lawyer takes right now: chat, call or both.
class LawyerChannels extends StatelessWidget {
  const LawyerChannels({super.key, required this.lawyer});
  final LawyerSummary lawyer;

  @override
  Widget build(BuildContext context) {
    Widget channel(IconData icon, bool on, String tip) => Tooltip(message: tip, child: Icon(icon, size: 15, color: on ? AppColors.greenAccent : AppColors.textGraySoft));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: lawyer.online ? AppColors.greenAccent : AppColors.textGraySoft, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(lawyer.online ? 'Online' : 'Offline', style: AppText.bodySmall(lawyer.online ? AppColors.greenAccent : AppColors.textGraySoft)),
      const SizedBox(width: 8),
      channel(Icons.chat_bubble_outline, lawyer.chatOnline, lawyer.chatOnline ? 'Taking chats' : 'Not taking chats'),
      const SizedBox(width: 6),
      channel(Icons.call_outlined, lawyer.callOnline, lawyer.callOnline ? 'Taking calls' : 'Not taking calls'),
    ]);
  }
}

/// "Chat" or "Call" button; disabled while the lawyer has that switched off.
class ChatCallButton extends StatelessWidget {
  const ChatCallButton({super.key, required this.lawyer, this.call = false, this.expand = false});
  final LawyerSummary lawyer;
  final bool call;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = call ? lawyer.callOnline : lawyer.chatOnline;
    final onPressed = enabled ? () => requestLawyer(context, lawyer, call: call) : null;
    final icon = Icon(call ? Icons.call_outlined : Icons.chat_bubble_outline, size: 16);
    final label = Text(call ? 'Call' : 'Chat');
    final size = expand ? const Size.fromHeight(46) : const Size(96, 36);
    return call
        ? OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label, style: OutlinedButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 12)))
        : FilledButton.icon(onPressed: onPressed, icon: icon, label: label, style: FilledButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 12)));
  }
}
