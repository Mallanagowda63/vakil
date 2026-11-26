import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dashboard_data.dart';
import '../../models/profile_data.dart';
import '../../models/session_book.dart';
import '../../models/theme_controller.dart';
import '../../models/wallet_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/law_points.dart';
import '../law_book_screen.dart';
import '../../widgets/lt_ui.dart';
import '../../widgets/metal_card.dart';
import 'partner_nav.dart';
import 'profile_panels.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning,' : h < 17 ? 'Good afternoon,' : 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final dash = context.watch<DashboardController>();
    final profile = context.watch<ProfileController>();
    final wallet = context.watch<WalletController>();
    final theme = context.watch<ThemeController>();
    final online = dash.onlineStatus;
    final waiting = dash.requests.length;

    return RefreshIndicator(
      color: c.brand,
      onRefresh: () async { await Future.wait([dash.loadEarnings(), dash.loadAvailability(), profile.load(), wallet.load()]); },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
        children: [
          Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(9)), child: Icon(Icons.balance, size: 18, color: c.brandInk)),
            const SizedBox(width: 8),
            Flexible(child: Text('Legally Talk', overflow: TextOverflow.ellipsis, style: sora(20, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.4))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.goldSoft, borderRadius: BorderRadius.circular(99)), child: Text('PARTNER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.gold))),
            const Spacer(),
            _IconBtn(icon: Icons.notifications_none_rounded, dot: waiting > 0, onTap: () => PartnerNav.openConsults(filter: 'incoming')),
            const SizedBox(width: 8),
            _IconBtn(icon: theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, onTap: () => theme.setDark(!theme.isDark)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: TextStyle(fontSize: 15, color: c.muted)),
              const SizedBox(height: 2),
              Text(profile.name.isEmpty ? 'Welcome' : 'Adv. ${profile.name}', style: sora(19, color: c.ink)),
            ]),
          ),
          MetalCard(online: online),
          const SizedBox(height: 12),
          LtCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(online ? 'Available for consults' : "You're offline", style: sora(15, color: c.ink)),
                const SizedBox(height: 5),
                StateChip(online ? 'Online · taking requests' : 'Requests paused', tone: online ? ChipTone.good : ChipTone.muted, icon: Icons.circle),
              ])),
              Switch(value: online, activeTrackColor: c.brand, onChanged: (v) {
                dash.setOnlineStatus(v);
                toast(context, v ? "You're online. Clients can find you." : "You're offline. New requests are paused.");
              }),
            ]),
            const SizedBox(height: 12),
            if (profile.languages.isNotEmpty) _meta(c, Icons.translate, profile.languages.replaceAll(',', ' ·')),
            _meta(c, Icons.schedule, [
              if (profile.experienceYears.isNotEmpty) '${profile.experienceYears} yrs at the Bar',
              '${wallet.consultationsDone} consults',
              if (dash.ratingAverage != null) '${dash.ratingAverage!.toStringAsFixed(1)} ★',
            ].join(' · ')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _RateTile(icon: Icons.chat_bubble_outline, label: 'Chat', rate: wallet.chatRate)),
              const SizedBox(width: 8),
              Expanded(child: _RateTile(icon: Icons.mic_none_rounded, label: 'Voice', rate: wallet.voiceRate)),
            ]),
            const SizedBox(height: 10),
            LinkButton('Set your price', onTap: () => showRatesSheet(context)),
          ])),
          const SizedBox(height: 12),
          LtCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _Service(first: true, icon: Icons.chat_bubble_outline, title: 'Chat consultations', text: dash.chatAllowed ? 'Clients can send you chat requests' : 'Turned off by the Vakil team',
                  value: dash.availableForChat && dash.chatAllowed, onChanged: dash.chatAllowed ? dash.setAvailableForChat : null),
              _Service(icon: Icons.mic_none_rounded, title: 'Voice consultations', text: dash.callAllowed ? 'Clients talk to you with voice messages' : 'Turned off by the Vakil team',
                  value: dash.availableForCall && dash.callAllowed, onChanged: dash.callAllowed ? dash.setAvailableForCall : null),
            ]),
          ),
          if (waiting > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => PartnerNav.openConsults(filter: 'incoming'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(Icons.notifications_active_outlined, color: c.brand),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(waiting == 1 ? '1 client is waiting' : '$waiting clients are waiting', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: c.ink)),
                    Text('Requests expire after 1 minute without a reply', style: TextStyle(fontSize: 12, color: c.muted)),
                  ])),
                  Icon(Icons.chevron_right, color: c.muted),
                ]),
              ),
            ),
          ],
          SecHead('Earnings', action: 'View ledger', onAction: () => PartnerNav.tab.value = PartnerNav.earnings),
          _EarningsCard(wallet: wallet),
          const SecHead('Tools'),
          Row(children: [
            Expanded(child: ListenableBuilder(
              listenable: SessionBook.instance,
              builder: (context, _) => _Tile(icon: Icons.event_note_outlined, title: 'Session book', text: SessionBook.instance.thisWeek == 1 ? '1 session this week' : '${SessionBook.instance.thisWeek} sessions this week', onTap: () => PartnerNav.openConsults(seg: 'sessions')),
            )),
            const SizedBox(width: 10),
            Expanded(child: _Tile(icon: Icons.menu_book_outlined, title: 'Law points', text: 'IPC → BNS, CrPC → BNSS, Evidence → BSA', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LawBookScreen(category: categoryOf(profile.categories.isNotEmpty ? profile.categories.first : profile.practiceArea)))))),
          ]),
        ],
      ),
    );
  }

  Widget _meta(LT c, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [Icon(icon, size: 15, color: c.muted), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.ink)))]),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.dot = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
        child: Stack(alignment: Alignment.center, children: [
          Icon(icon, size: 20, color: c.ink),
          if (dot) Positioned(top: 8, right: 9, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.bad, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)))),
        ]),
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({required this.icon, required this.label, required this.rate});
  final IconData icon;
  final String label;
  final double rate;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 13, color: c.muted), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 11, color: c.muted))]),
        Text.rich(TextSpan(children: [
          TextSpan(text: rate > 0 ? inr(rate) : '—', style: sora(15, color: c.ink)),
          TextSpan(text: '/min', style: TextStyle(fontSize: 11, color: c.muted)),
        ])),
      ]),
    );
  }
}

class _Service extends StatelessWidget {
  const _Service({required this.icon, required this.title, required this.text, required this.value, required this.onChanged, this.first = false});
  final IconData icon;
  final String title, text;
  final bool value, first;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: c.line))),
      child: Row(children: [
        Initials('', icon: icon, iconBg: c.brandSoft, size: 38),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: c.ink)),
          Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
        ])),
        Switch(value: value, activeTrackColor: c.brand, onChanged: onChanged),
      ]),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.wallet});
  final WalletController wallet;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final days = wallet.last7Days;
    final max = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    Widget kpi(String label, double v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
          Text(inr(v), style: sora(18, color: c.ink)),
        ]));
    return LtCard(child: Column(children: [
      Row(children: [kpi('Today', wallet.todayEarnings), kpi('This week', wallet.weekEarnings), kpi(_months[DateTime.now().month - 1], wallet.monthNet)]),
      const SizedBox(height: 18),
      SizedBox(
        height: 120,
        child: days.isEmpty
            ? Center(child: Text('Your earnings will show here', style: TextStyle(fontSize: 12, color: c.muted)))
            : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(child: LayoutBuilder(builder: (context, box) {
                    final today = i == days.length - 1;
                    final top = max > 0 && days[i].amount == max;
                    final h = max == 0 ? 3.0 : (days[i].amount / max * (box.maxHeight - 18)).clamp(3.0, box.maxHeight - 18);
                    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if ((today || top) && days[i].amount > 0) Text(inr(days[i].amount), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.ink)),
                      const SizedBox(height: 4),
                      Container(width: 26, height: h, decoration: BoxDecoration(color: today ? c.brand : top ? c.gold : c.brandSoft, borderRadius: const BorderRadius.vertical(top: Radius.circular(7), bottom: Radius.circular(3)))),
                    ]);
                  })),
              ]),
      ),
      Divider(height: 1, color: c.line),
      const SizedBox(height: 6),
      if (days.isNotEmpty) Row(children: [
        for (var i = 0; i < days.length; i++)
          Expanded(child: Text(i == days.length - 1 ? 'Today' : _days[days[i].day.weekday - 1], textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: i == days.length - 1 ? c.brand : c.muted, fontWeight: i == days.length - 1 ? FontWeight.w700 : FontWeight.w400))),
      ]),
    ]));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: c.goldSoft, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: c.gold)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
          const SizedBox(height: 2),
          Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
        ]),
      ),
    );
  }
}
