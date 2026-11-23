import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dashboard_data.dart';
import '../../models/profile_data.dart';
import '../../models/wallet_data.dart';
import '../../services/partner_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lt_ui.dart';
import '../../widgets/metal_card.dart';
import '../customer_support_screen.dart';
import '../feedback_screen.dart';
import '../login_otp_screen.dart';
import '../payout_methods_screen.dart';
import '../settings_screen.dart';
import 'profile_panels.dart';

/// Profile: the partner card, what is still missing, and everything editable.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You go offline and need to sign in again to take consultations.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, true), style: FilledButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Sign out')),
      ],
    ));
    if (ok != true || !context.mounted) return;
    final controller = context.read<DashboardController>();
    final token = PartnerAuthService.instance.token;
    if (token != null) { try { await controller.consultationService.presence(token, false); } catch (_) {} }
    controller.disconnect();
    await PartnerAuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginOtpScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final p = context.watch<ProfileController>();
    final w = context.watch<WalletController>();
    final dash = context.watch<DashboardController>();
    final payout = p.hasPayout || w.hasUpi || w.hasBank;
    final steps = <(String, bool, String)>[
      ('Bar Council number', p.barCouncilVerified, p.barCouncilVerified ? 'Verified by email' : 'Not verified'),
      ('Advocate licence', p.hasLicence, p.hasLicence ? 'Uploaded' : 'Missing'),
      ('Face verification photo', p.hasFacePhoto, p.hasFacePhoto ? 'Uploaded' : 'Missing'),
      ('Payout account', payout, payout ? (w.hasUpi ? 'UPI' : w.hasBank ? 'Bank ····${w.bankAccountLast4}' : 'Added') : 'Add one'),
      ('Profile photo', p.photoUrl != null, p.photoUrl != null ? 'Added' : 'Tap the card photo'),
    ];
    final done = steps.where((s) => s.$2).length;
    final percent = (done / steps.length * 100).round();
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return RefreshIndicator(
      color: c.brand,
      onRefresh: () async { await Future.wait([p.load(), w.load()]); },
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 120), children: [
        Text('Profile', style: sora(28, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        MetalCard(online: dash.onlineStatus),
        if (!payout) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => push(const PayoutMethodsScreen()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.goldSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.gold.withValues(alpha: 0.35))),
              child: Row(children: [
                Icon(Icons.shield_outlined, color: c.gold),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add a payout account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: c.ink)),
                  Text('Add a UPI ID or bank account so the Vakil team can pay you.', style: TextStyle(fontSize: 12, color: c.muted)),
                ])),
                Icon(Icons.chevron_right, color: c.muted),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 14),
        LtCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Eyebrow('Profile strength')), Text('$percent%', style: TextStyle(fontWeight: FontWeight.w700, color: c.gold))]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(height: 8, color: c.surface2, alignment: Alignment.centerLeft, child: FractionallySizedBox(
              widthFactor: done / steps.length,
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gold, c.brand]))),
            )),
          ),
          const SizedBox(height: 14),
          for (final s in steps) Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: s.$2 ? c.good : null, border: s.$2 ? null : Border.all(color: c.muted, width: 1.5)),
                child: s.$2 ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.$1, style: TextStyle(fontSize: 13.5, color: c.ink))),
              Text(s.$3, style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
          ),
        ])),
        const SecHead('Professional profile'),
        LtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
          _row(c, Icons.person_outline, 'Personal details', [p.phone, p.email].where((x) => x.isNotEmpty).join(' · '), () => showPersonalSheet(context), first: true),
          _row(c, Icons.balance, 'Practice areas & courts', [p.categories.join(', '), p.court].where((x) => x.isNotEmpty).join(' · '), () => showPracticeSheet(context)),
          _row(c, Icons.currency_rupee, 'Your prices', 'Chat ${inr(w.chatRate)} · Voice ${inr(w.voiceRate)} per min', () => showRatesSheet(context)),
          _row(c, Icons.account_balance_outlined, 'Bank & payouts', payout ? w.defaultMethodSummary : 'Not added yet', () => push(const PayoutMethodsScreen())),
          _row(c, Icons.star_outline_rounded, 'Reviews', dash.ratingAverage == null ? 'No ratings yet' : '${dash.ratingAverage!.toStringAsFixed(1)} from ${dash.ratingCount} ${dash.ratingCount == 1 ? 'rating' : 'ratings'}', () => push(const FeedbackScreen())),
          _row(c, Icons.help_outline, 'Help & support', 'Write to the Vakil team', () => push(const CustomerSupportScreen())),
          _row(c, Icons.settings_outlined, 'Settings', 'Notifications, sound and appearance', () => push(const SettingsScreen())),
          LtRow(leading: Initials('', icon: Icons.logout, iconBg: c.badSoft, iconColor: c.bad), title: 'Sign out', titleColor: c.bad, onTap: () => _signOut(context)),
        ])),
      ]),
    );
  }

  Widget _row(LT c, IconData icon, String title, String sub, VoidCallback onTap, {bool first = false}) =>
      LtRow(first: first, leading: Initials('', icon: icon, iconBg: c.brandSoft), title: title, subtitle: sub, onTap: onTap, trailing: Icon(Icons.chevron_right, color: c.muted));
}
