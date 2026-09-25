import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/consultation_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/add_time_sheet.dart';
import '../widgets/wallet_widgets.dart';
import 'lawyers_screen.dart';
import 'live_consultation_chat_screen.dart';
import 'wallet_screen.dart';

enum _Phase { form, waiting, declined }

/// Sends a chat request, waits for the lawyer (Cancel allowed), opens the chat
/// the moment it is accepted, and suggests other lawyers after a reject/expiry.
class RequestConsultationScreen extends StatefulWidget {
  const RequestConsultationScreen({super.key, this.lawyerId, required this.lawyerName, required this.category, this.photoUrl, this.ratePerMinute, this.consultationType = 'chat'});
  /// Null lets the server pick any online lawyer for [category].
  final String? lawyerId;
  final String lawyerName;
  final String category;
  final String? photoUrl;
  /// The lawyer's price after the free trial (shown before sending).
  final double? ratePerMinute;
  /// 'call': when the lawyer accepts, the chat opens and the voice call starts.
  final String consultationType;
  @override
  State<RequestConsultationScreen> createState() => _State();
}

class _State extends State<RequestConsultationScreen> {
  final _service = ConsultationService();
  final _issue = TextEditingController();
  StreamSubscription<SocketEvent>? _events;
  Timer? _poll;
  Timer? _tick;
  _Phase _phase = _Phase.form;
  Map<String, dynamic>? _request;
  String? _declinedMessage;
  List<LawyerSummary> _suggestions = const [];
  bool _busy = false;
  bool _opened = false;
  String? _error;
  // Paid chat: the minutes bought up front.
  int _minutes = packageMinutes.first;

  bool get _freeTrial => !AuthService.instance.trialUsed;
  String get _actionLabel => widget.consultationType == 'call' ? 'Call Lawyer' : 'Chat with Lawyer';
  bool get _paidChat => !_freeTrial && (widget.ratePerMinute ?? 0) > 0;
  String? get _requestId => _request?['id']?.toString();
  int get _secondsLeft {
    final expires = DateTime.tryParse(_request?['expiresAt']?.toString() ?? '');
    return expires == null ? 0 : expires.difference(DateTime.now()).inSeconds.clamp(0, 60);
  }

  @override
  void initState() {
    super.initState();
    _events = RealtimeService.instance.events.stream.listen((event) {
      if (event.name == 'connect') { _refresh(); return; }
      if (event.data['id']?.toString() == _requestId && event.name.startsWith('request_')) _apply(event.data);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _poll?.cancel();
    _tick?.cancel();
    _issue.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() { _busy = true; _error = null; });
    try {
      final request = await _service.create(lawyerId: widget.lawyerId, category: widget.category, description: _issue.text.trim(), consultationType: widget.consultationType, minutes: _paidChat ? _minutes : null);
      if (!mounted) return;
      setState(() { _request = request; _phase = _Phase.waiting; });
      // Sockets are the fast path; polling covers a missed event.
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 402: not enough in the wallet for the minutes chosen.
      if (e.statusCode == 402) {
        setState(() => _error = null);
        openWallet(context, message: _paidChat ? 'Add money to buy $_minutes minutes with this lawyer' : 'Add money to chat with this lawyer');
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final id = _requestId;
    if (id == null || _phase != _Phase.waiting) return;
    try { _apply(await _service.getRequest(id)); } catch (_) {}
  }

  void _apply(Map<String, dynamic> request) {
    if (!mounted || _phase != _Phase.waiting) return;
    final status = request['status']?.toString();
    if (status == 'ONGOING') return _openChat();
    if (status == 'REJECTED' || status == 'EXPIRED') {
      _poll?.cancel();
      _tick?.cancel();
      setState(() {
        _phase = _Phase.declined;
        _declinedMessage = status == 'REJECTED' ? '${widget.lawyerName} is not available right now.' : '${widget.lawyerName} did not respond in time.';
      });
      _loadSuggestions();
    } else if (status == 'CANCELLED') {
      _poll?.cancel();
      _tick?.cancel();
      // The wallet no longer covered the first minute when the lawyer accepted.
      if (request['cancelReason'] == 'insufficient_balance') {
        _phase = _Phase.declined;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WalletScreen(message: 'Your balance ran out before the lawyer accepted. Add money to chat with this lawyer.')));
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _openChat() {
    if (_opened) return;
    _opened = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LiveConsultationChatScreen(requestId: _requestId!, title: widget.lawyerName, photoUrl: widget.photoUrl, startCall: widget.consultationType == 'call')));
  }

  Future<void> _loadSuggestions() async {
    try {
      final lawyers = await _service.lawyers();
      if (mounted) setState(() => _suggestions = lawyers.where((l) => l.online && l.id != widget.lawyerId).take(3).toList());
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final id = _requestId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await _service.cancel(id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      // Accepted in the same moment: open the chat instead.
      await _refresh();
      if (mounted && !_opened) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Cancel request?'),
      content: Text('${widget.lawyerName} has not accepted yet.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep waiting')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel request'))],
    ));
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.waiting,
      onPopInvokedWithResult: (didPop, _) async { if (!didPop && await _confirmLeave()) _cancel(); },
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(title: Text(widget.consultationType == 'call' ? 'Call Lawyer' : 'Chat with Lawyer'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: switch (_phase) {
          _Phase.form => _form(),
          _Phase.waiting => _waiting(),
          _Phase.declined => _declined(),
        })),
      ),
    );
  }

  Widget _trialBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.greenAccent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
        child: Text('Your first chat is FREE for 1 minute', textAlign: TextAlign.center, style: AppText.bodyMedium(AppColors.greenAccent)),
      );

  // Paid chat: how many minutes to buy, their price, and what is in the wallet.
  Widget _priceBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Buy time · ${formatRate(widget.ratePerMinute!)}', style: AppText.bodyMedium(AppColors.textDark))),
            const WalletButton(),
          ]),
          const SizedBox(height: 10),
          MinutePicker(rate: widget.ratePerMinute!, selected: _minutes, onSelected: (m) => setState(() => _minutes = m)),
          const SizedBox(height: 8),
          Text('Paid when the lawyer accepts. Chat and calls end when the time is up; you can add more time during the chat.', style: AppText.caption(AppColors.textGray)),
        ]),
      );

  Widget _form() =>Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          LawyerAvatar(name: widget.lawyerName, photoUrl: widget.photoUrl, radius: 28),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.lawyerName, style: AppText.h2(AppColors.textDark)), Text(widget.category, style: AppText.body(AppColors.textGray))])),
        ]),
        const SizedBox(height: 20),
        if (_freeTrial) ...[_trialBanner(), const SizedBox(height: 16)]
        else if (_paidChat) ...[_priceBanner(), const SizedBox(height: 16)],
        TextField(controller: _issue, maxLines: 5, maxLength: 1000, decoration: const InputDecoration(labelText: 'Describe your issue (optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: AppText.body(AppColors.redAccent))),
        const Spacer(),
        FilledButton(onPressed: _busy ? null : _send, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(_busy ? 'Sending…' : _paidChat ? '$_actionLabel · ${formatCurrency(_minutes * widget.ratePerMinute!)}' : _actionLabel)),
      ]);

  Widget _waiting() => Column(children: [
        const Spacer(),
        LawyerAvatar(name: widget.lawyerName, photoUrl: widget.photoUrl, radius: 44),
        const SizedBox(height: 20),
        Text('Waiting for ${widget.lawyerName} to accept...', textAlign: TextAlign.center, style: AppText.h3(AppColors.textDark)),
        const SizedBox(height: 8),
        Text('${_secondsLeft}s', style: AppText.body(AppColors.textGray)),
        const SizedBox(height: 20),
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        if (_request?['isTrial'] == true) ...[const SizedBox(height: 24), _trialBanner()],
        const Spacer(),
        OutlinedButton(onPressed: _busy ? null : _cancel, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Cancel')),
      ]);

  Widget _declined() => ListView(children: [
        const SizedBox(height: 24),
        Icon(Icons.info_outline, size: 48, color: AppColors.textGray),
        const SizedBox(height: 12),
        Text(_declinedMessage ?? '', textAlign: TextAlign.center, style: AppText.h3(AppColors.textDark)),
        const SizedBox(height: 6),
        Text('Please choose another lawyer.', textAlign: TextAlign.center, style: AppText.body(AppColors.textGray)),
        const SizedBox(height: 24),
        if (_suggestions.isNotEmpty) ...[
          Text('Available now', style: AppText.label(AppColors.textGray)),
          const SizedBox(height: 10),
          for (final lawyer in _suggestions) Padding(padding: const EdgeInsets.only(bottom: 10), child: LawyerRow(lawyer: lawyer)),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LawyersScreen(excludeLawyerId: widget.lawyerId))),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('See all lawyers'),
        ),
      ]);
}
