import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/profile_data.dart';
import '../../models/wallet_data.dart';
import '../../services/consultation_service.dart';
import '../../services/partner_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lt_ui.dart';

// Bottom sheets opened from Profile and Home: prices, personal details, practice.

/// The practice areas lawyers pick at registration; clients' search matches these names.
const practiceOptions = ['Civil & Family Law', 'Criminal Law', 'Corporate Law', 'Property Law', 'Labour & Service Law', 'Tax Law', 'Constitutional Law', 'Consumer Protection', 'Intellectual Property'];
const languageOptions = ['English', 'Kannada', 'Hindi', 'Marathi', 'Telugu', 'Tamil', 'Urdu'];

InputDecoration _field(BuildContext context, String hint) {
  final c = LT.of(context);
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: c.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.brand, width: 2)),
  );
}

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LT.of(context).muted)),
    );

/// Chat price per minute (the lawyer's own) and the voice price (set by Vakil).
Future<void> showRatesSheet(BuildContext context) {
  final wallet = context.read<WalletController>();
  var rate = wallet.chatRate > 0 ? wallet.chatRate.round() : 20;
  const minRate = 10, maxRate = 50;
  var saving = false;
  final keep = (100 - (wallet.commissionPercent > 0 ? wallet.commissionPercent : 20)) / 100;
  return showLtSheet(context, title: 'Your prices', builder: (sheet) => StatefulBuilder(builder: (context, setState) {
    final c = LT.of(context);
    Widget stepBtn(String t, int d) => SizedBox(width: 36, height: 40, child: TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: c.brand),
          onPressed: () => setState(() => rate = (rate + d).clamp(minRate, maxRate)),
          child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(16)),
        child: Text('Set your chat price per minute, from ₹$minRate to ₹$maxRate. Clients see the new price on their next request. Legally Talk keeps ${(100 - keep * 100).round()}%.', style: TextStyle(fontSize: 12.5, height: 1.5, color: c.ink)),
      ),
      const SizedBox(height: 12),
      LtCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          LtRow(
            first: true,
            leading: Initials('', icon: Icons.chat_bubble_outline, iconBg: c.brandSoft, size: 38),
            title: 'Chat',
            subtitle: 'You earn ${inr(rate * keep)}/min · ${inr(rate * 10)} for 10 min',
            trailing: Container(
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [stepBtn('−', -1), Text('₹$rate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.ink)), stepBtn('+', 1)]),
            ),
          ),
          LtRow(
            leading: Initials('', icon: Icons.mic_none_rounded, iconBg: c.brandSoft, size: 38),
            title: 'Voice consultations',
            subtitle: 'Same price for every lawyer, set by Vakil',
            trailing: Text('${inr(wallet.voiceRate)}/min', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: LtButton('Save price', icon: Icons.check, loading: saving, onTap: () async {
        final token = PartnerAuthService.instance.token;
        if (token == null) return;
        setState(() => saving = true);
        try {
          wallet.chatRate = await PartnerConsultationService().setRate(token, rate.toDouble());
          wallet.load();
          if (sheet.mounted) { Navigator.pop(sheet); toast(context, 'Chat price is now ₹$rate per minute'); }
        } on PartnerNetworkException catch (e) {
          setState(() => saving = false);
          if (context.mounted) toast(context, e.message);
        }
      })),
    ]);
  }));
}

/// Name, email, chamber address, years at the Bar. Enrolment and mobile are read-only.
Future<void> showPersonalSheet(BuildContext context) {
  final p = context.read<ProfileController>();
  final name = TextEditingController(text: p.name), email = TextEditingController(text: p.email), address = TextEditingController(text: p.address), years = TextEditingController(text: p.experienceYears);
  var saving = false;
  return showLtSheet(context, title: 'Personal details', builder: (sheet) => StatefulBuilder(builder: (context, setState) {
    final c = LT.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(context, 'Full name (shown as Adv. …)'),
      TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: _field(context, 'Your full name')),
      _label(context, 'Email'),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _field(context, 'name@example.com')),
      _label(context, 'Chamber / office address'),
      TextField(controller: address, minLines: 2, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: _field(context, 'Chamber, court complex, city')),
      _label(context, 'Years at the Bar'),
      TextField(controller: years, keyboardType: TextInputType.number, decoration: _field(context, 'e.g. 4')),
      const SizedBox(height: 10),
      Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: c.muted, height: 1.5), children: [
        const TextSpan(text: 'Your mobile '),
        TextSpan(text: p.phone.isEmpty ? '(not added)' : p.phone, style: mono(12, color: c.ink)),
        const TextSpan(text: ' and enrolment number '),
        TextSpan(text: p.barCouncilRegNo.isEmpty ? '(not added)' : p.barCouncilRegNo, style: mono(12, color: c.ink)),
        const TextSpan(text: ' are verified; write to Help & support to change them.'),
      ])),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: LtButton('Save details', icon: Icons.check, loading: saving, onTap: () async {
        setState(() => saving = true);
        try {
          await p.update({'fullName': name.text.trim().replaceFirst(RegExp(r'^Adv\.?\s*', caseSensitive: false), ''), 'email': email.text.trim(), 'address': address.text.trim(), if (years.text.trim().isNotEmpty) 'experienceYears': years.text.trim()});
          if (sheet.mounted) { Navigator.pop(sheet); toast(context, 'Personal details saved'); }
        } on PartnerNetworkException catch (e) {
          setState(() => saving = false);
          if (context.mounted) toast(context, e.message);
        }
      })),
    ]);
  }));
}

/// Practice areas (up to 4), languages and courts.
Future<void> showPracticeSheet(BuildContext context) {
  final p = context.read<ProfileController>();
  final areas = [...p.categories.where(practiceOptions.contains)];
  if (areas.isEmpty && practiceOptions.contains(p.practiceArea)) areas.add(p.practiceArea);
  final langs = p.languages.split(RegExp(r'[,·]')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final courts = TextEditingController(text: p.court);
  var saving = false;
  return showLtSheet(context, title: 'Practice areas & courts', builder: (sheet) => StatefulBuilder(builder: (context, setState) {
    final c = LT.of(context);
    Widget toggle(String label, bool on, VoidCallback tap) => GestureDetector(
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: on ? c.brand : c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? c.brand : c.line)),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? c.brandInk : c.ink)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('Practice areas · pick up to 4'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in practiceOptions) toggle(a, areas.contains(a), () => setState(() {
          if (areas.contains(a)) {
            if (areas.length > 1) { areas.remove(a); } else { toast(context, 'Keep at least one practice area'); }
          }
          else if (areas.length >= 4) { toast(context, 'You can pick up to 4 areas'); }
          else { areas.add(a); }
        })),
      ]),
      const SizedBox(height: 16),
      const Eyebrow('Languages'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in languageOptions) toggle(l, langs.contains(l), () => setState(() => langs.contains(l) ? (langs.length > 1 ? langs.remove(l) : null) : langs.add(l))),
      ]),
      _label(context, 'Courts you appear in'),
      TextField(controller: courts, decoration: _field(context, 'e.g. Hubballi–Dharwad')),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: LtButton('Save practice', icon: Icons.check, loading: saving, onTap: () async {
        setState(() => saving = true);
        try {
          await p.setCategories(areas);
          await p.update({'languages': langs.join(', '), 'court': courts.text.trim()});
          if (sheet.mounted) { Navigator.pop(sheet); toast(context, 'Practice areas saved'); }
        } on PartnerNetworkException catch (e) {
          setState(() => saving = false);
          if (context.mounted) toast(context, e.message);
        }
      })),
    ]);
  }));
}
