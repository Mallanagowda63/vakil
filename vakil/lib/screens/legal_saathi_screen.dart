import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/legal_saathi_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/wallet_widgets.dart';
import 'lawyer_profile_screen.dart';
import 'lawyers_screen.dart';

/// Legal Saathi (AI): the client describes their problem and gets the right
/// Vakil lawyers for it, ranked on practice area, client ratings and reviews,
/// experience, price and who is available now. Tapping a lawyer opens their
/// profile, where the client starts a chat or call as usual.
class LegalSaathiScreen extends StatefulWidget {
  const LegalSaathiScreen({super.key});
  @override
  State<LegalSaathiScreen> createState() => _LegalSaathiScreenState();
}

class _Turn {
  _Turn.user(this.text) : mine = true, answer = null;
  _Turn.saathi(SaathiAnswer this.answer) : mine = false, text = answer.reply;
  final bool mine;
  final String text;
  final SaathiAnswer? answer;
}

class _LegalSaathiScreenState extends State<LegalSaathiScreen> {
  static const _examples = ['Police filed an FIR against my brother', 'I want a divorce', 'My landlord is not returning my deposit', 'My salary has not been paid'];

  final _service = LegalSaathiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    final history = [for (final t in _turns) {'role': t.mine ? 'user' : 'assistant', 'text': t.text}];
    _input.clear();
    setState(() { _turns.add(_Turn.user(text)); _thinking = true; });
    _scrollToEnd();
    try {
      final answer = await _service.ask(text, history: history);
      if (mounted) setState(() => _turns.add(_Turn.saathi(answer)));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _turns.removeLast());
        _input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  void _open(LawyerSummary lawyer) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LawyerProfileScreen(lawyer: lawyer)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.aiCardStart, AppColors.aiCardEnd]), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Legal Saathi', style: AppText.h3(AppColors.textDark)),
            Text('Finds the right lawyer for you', style: AppText.caption(AppColors.textGray)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            children: [
              _SaathiBubble(text: 'Namaste! Tell me about your legal problem in your own words, in any language. I will suggest the best Vakil lawyers for it, based on their practice area, client ratings and reviews, experience and price.'),
              if (_turns.isEmpty) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final example in _examples)
                    ActionChip(
                      label: Text(example, style: AppText.bodySmall(AppColors.aiCardEnd)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.lightStroke),
                      onPressed: () => _ask(example),
                    ),
                ]),
              ],
              for (final turn in _turns)
                if (turn.mine) _UserBubble(text: turn.text) else ...[
                  _SaathiBubble(text: turn.text),
                  for (final pick in turn.answer!.lawyers) _SuggestedLawyerCard(pick: pick, onTap: () => _open(pick.lawyer)),
                ],
              if (_thinking) const _SaathiBubble(text: 'Finding the right lawyers for you…', typing: true),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text('Legal Saathi is an AI guide, not legal advice. Your lawyer gives the advice.', textAlign: TextAlign.center, style: AppText.caption(AppColors.textGray)),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: 'Describe your problem…', filled: true, fillColor: const Color(0xFFF1F3F6), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _thinking ? null : _ask,
                style: IconButton.styleFrom(backgroundColor: AppColors.aiCardEnd),
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6, left: 48),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(color: Color(0xFF171722), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4))),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      );
}

class _SaathiBubble extends StatelessWidget {
  const _SaathiBubble({required this.text, this.typing = false});
  final String text;
  final bool typing;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8, right: 36),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (typing) ...[const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.aiCardEnd)), const SizedBox(width: 10)],
            Flexible(child: Text(text, style: TextStyle(fontSize: 15, height: 1.35, color: typing ? AppColors.textGray : Colors.black87))),
          ]),
        ),
      );
}

/// One suggested lawyer: photo, practice areas, rating, experience, prices,
/// whether they are available now, and why Legal Saathi picked them.
class _SuggestedLawyerCard extends StatelessWidget {
  const _SuggestedLawyerCard({required this.pick, required this.onTap});
  final SuggestedLawyer pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = pick.lawyer;
    final facts = [
      if (l.ratingAverage != null) '★ ${l.ratingAverage!.toStringAsFixed(1)} (${l.ratingCount})',
      if (l.experienceYears != null) '${l.experienceYears} yrs exp',
      if (l.consultationsDone > 0) '${l.consultationsDone} consultations',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightStroke)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                LawyerAvatar(name: l.name, photoUrl: l.photoUrl, online: l.online, radius: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: AppText.bodyMedium(AppColors.textDark).copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(l.categories.isEmpty ? 'Lawyer' : l.categories.join(', '), style: AppText.caption(AppColors.textGray), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (facts.isNotEmpty) Text(facts.join(' · '), style: AppText.caption(AppColors.textDark).copyWith(fontWeight: FontWeight.w600)),
                ])),
                const Icon(Icons.chevron_right, color: AppColors.textGray),
              ]),
              if (pick.reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFFF1EFFF), borderRadius: BorderRadius.circular(10)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.aiCardEnd),
                    const SizedBox(width: 6),
                    Expanded(child: Text(pick.reason, style: AppText.caption(AppColors.aiCardEnd).copyWith(fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                _Price(icon: Icons.chat_bubble_outline, label: 'Chat ${formatRate(l.ratePerMinute)}', on: l.chatOnline),
                const SizedBox(width: 8),
                _Price(icon: Icons.call_outlined, label: 'Call ${formatRate(l.rateFor(call: true))}', on: l.callOnline),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A price chip, green when the lawyer takes that kind of consultation right now.
class _Price extends StatelessWidget {
  const _Price({required this.icon, required this.label, required this.on});
  final IconData icon;
  final String label;
  final bool on;
  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.greenAccent : AppColors.textGray;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: on ? const Color(0xFFE8F7EE) : AppColors.lightSurface, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: AppText.caption(color).copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
