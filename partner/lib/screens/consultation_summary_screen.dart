import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'dashboard_screen.dart';
import 'feedback_screen.dart';

/// Shown to the lawyer when a consultation ends: what the client paid, how
/// long it ran, the rate and what the lawyer earned after commission — all
/// from the server (GET /api/consultations/:id). "Session Disconnected" when
/// the client's time or balance ran out.
class ConsultationSummaryScreen extends StatefulWidget {
  final String requestId;
  final String clientName;

  const ConsultationSummaryScreen({super.key, required this.requestId, required this.clientName});

  @override
  State<ConsultationSummaryScreen> createState() => _ConsultationSummaryScreenState();
}

class _ConsultationSummaryScreenState extends State<ConsultationSummaryScreen> {
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _earning;
  String? _error;
  /// Feedback for this consultation: mine (lawyer → client) and theirs (client → me).
  Map<String, dynamic>? _myFeedback;
  Map<String, dynamic>? _theirFeedback;
  final _comment = TextEditingController();
  int _stars = 0;
  bool _sendingFeedback = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFeedback();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadFeedback() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      final data = await PartnerConsultationService().feedbackFor(widget.requestId, token);
      if (!mounted) return;
      setState(() {
        _myFeedback = data['mine'] == null ? null : Map<String, dynamic>.from(data['mine'] as Map);
        _theirFeedback = data['theirs'] == null ? null : Map<String, dynamic>.from(data['theirs'] as Map);
      });
    } catch (_) {}
  }

  Future<void> _sendFeedback() async {
    final token = PartnerAuthService.instance.token;
    if (token == null || _stars == 0) return;
    setState(() => _sendingFeedback = true);
    try {
      final res = await PartnerConsultationService().review(widget.requestId, token, _stars, _comment.text.trim());
      if (!mounted) return;
      setState(() => _myFeedback = Map<String, dynamic>.from(res['feedback'] as Map));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks — your feedback was sent')));
    } on PartnerNetworkException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  Widget _feedbackSection() {
    final mine = _myFeedback;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR FEEDBACK ON THE CLIENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.4)),
      const SizedBox(height: 10),
      if (mine != null)
        FeedbackCard(item: mine)
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How was your consultation with $_clientName?', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            const Text('Shared with the client and the Vakil team.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var s = 1; s <= 5; s++)
                IconButton(iconSize: 36, onPressed: () => setState(() => _stars = s), icon: Icon(s <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF5A623))),
            ]),
            TextField(controller: _comment, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'Add a comment (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 6),
            PrimaryButton(label: _sendingFeedback ? 'Sending…' : 'Submit feedback', onPressed: _stars == 0 || _sendingFeedback ? null : _sendFeedback),
          ]),
        ),
      if (_theirFeedback != null) ...[
        const SizedBox(height: 16),
        const Text("CLIENT'S RATING OF YOU", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        FeedbackCard(item: _theirFeedback!),
      ],
    ]);
  }

  Future<void> _load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    setState(() => _error = null);
    try {
      final data = await PartnerConsultationService().getRequest(widget.requestId, token);
      if (!mounted) return;
      setState(() {
        _request = Map<String, dynamic>.from(data['request'] as Map);
        _earning = data['earning'] == null ? null : Map<String, dynamic>.from(data['earning'] as Map);
      });
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String get _endReason => _request?['endReason']?.toString() ?? '';
  bool get _disconnected => _endReason == 'time_over' || _endReason == 'balance_over';
  String get _clientName => _request?['userName']?.toString() ?? widget.clientName;
  double _money(String key, [Map<String, dynamic>? from]) => ((from ?? _request)?[key] as num?)?.toDouble() ?? 0;
  int get _durationMinutes => (((_request?['durationSeconds'] as num?) ?? 0) / 60).ceil();

  Future<void> _reportUser() async {
    const reasons = ['Abusive or rude', 'Spam or fake request', 'Asked for contact details', 'Technical problem', 'Other'];
    String? reason;
    final details = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialog) => AlertDialog(
        title: Text('Report $_clientName'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('The Vakil team reviews every report. The client is not told who reported them.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in reasons) ChoiceChip(label: Text(r), selected: reason == r, onSelected: (_) => setDialog(() => reason = r)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: details, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'What happened? (optional)', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: reason == null ? null : () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Send report'),
          ),
        ],
      )),
    );
    final token = PartnerAuthService.instance.token;
    if (send != true || reason == null || token == null || !mounted) return;
    try {
      final res = await PartnerConsultationService().report(widget.requestId, token, reason: reason!, details: details.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report sent (${res['ticket']}). Our team will look into it.')));
    } on PartnerNetworkException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  /// What the client asked, the practice area, how long it ran and how it ended.
  Widget _sessionCard() {
    final issue = _request?['description']?.toString().trim() ?? '';
    final category = _request?['category']?.toString() ?? '';
    final ended = _disconnected ? "Client's ${_endReason == 'balance_over' ? 'balance' : 'time'} ran out" : _request?['endedBy'] == 'lawyer' ? 'Ended by you' : _request?['endedBy'] == 'user' ? 'Ended by the client' : 'Completed';
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35))),
          ]),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row(Icons.person_outline, 'Client', _clientName),
        if (category.isNotEmpty) row(Icons.balance, 'Area', category),
        if (issue.isNotEmpty) row(Icons.chat_bubble_outline, 'Question', issue),
        row(Icons.timer_outlined, 'Duration', '$_durationMinutes min'),
        row(Icons.flag_outlined, 'Ended', ended),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_request == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: _load, child: const Text('Try again'))]),
          ),
        ),
      );
    }
    final trial = _request!['isTrial'] == true;
    final rate = _money('ratePerMinute');
    final earned = _earning == null ? null : _money('amount', _earning);
    final commission = _earning == null ? 0.0 : _money('commission', _earning);
    final percent = (_earning?['commissionPercent'] as num?)?.toDouble();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _disconnected ? 'Session Disconnected' : 'Consultation Summary',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _disconnected ? "The client's ${_endReason == 'balance_over' ? 'balance' : 'time'} ran out" : 'Review your session details below.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBDBFC)),
                ),
                child: Column(
                  children: [
                    const Text('FINAL CHARGE', style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: AppColors.primaryDark)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${_money('totalAmount').toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connected duration: $_durationMinutes mins • ${trial && _money('totalAmount') == 0 ? 'Free trial' : 'Rate: ${rupees(rate)} / min'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Billing is based on server-side connected duration.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (earned != null) ...[
                      const Divider(height: 22),
                      Text(
                        'You earned ${rupees(earned)}${commission > 0 ? ' (after ${rupees(commission)} commission${percent == null ? '' : ', ${percent % 1 == 0 ? percent.toInt() : percent}%'})' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ],
                ),
              ),
              if (_disconnected) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF5DCC0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(color: Color(0xFFFDE7D3), shape: BoxShape.circle),
                        child: const Icon(Icons.error_outline, size: 16, color: Color(0xFFB5751B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Session disconnected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(
                              _endReason == 'balance_over'
                                  ? "The client's balance dropped too low to continue the chat or call."
                                  : 'The time the client bought ran out, so the chat and any call ended.',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'The client can start a new consultation with you to continue.',
                              style: TextStyle(fontSize: 11, color: Color(0xFFB5751B), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _sessionCard(),
              const SizedBox(height: 22),
              _feedbackSection(),
              const SizedBox(height: 22),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5C2C2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report user', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 4),
                    const Text(
                      'If the consultation involved technical issues, abusive conduct, or spam, report the user for review.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _reportUser,
                      child: const Text(
                        'Report user',
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: 'Go to Dashboard', onPressed: _goToDashboard),
            ],
          ),
        ),
      ),
    );
  }
}
