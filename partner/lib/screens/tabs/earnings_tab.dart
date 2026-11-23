import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/wallet_data.dart';
import '../../services/partner_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/chat_format.dart';
import '../../widgets/lt_ui.dart';
import '../payout_methods_screen.dart';
import '../wallet_history_screen.dart';

/// Earnings: the balance ready for payout, this month by chat and voice, and the ledger.
class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});
  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  bool _requesting = false;
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  Future<void> _requestPayout(WalletController wallet) async {
    if (!wallet.hasUpi && !wallet.hasBank) {
      toast(context, 'Add a UPI ID or bank account first');
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Request payout?'),
      content: Text('${inr(wallet.availableBalance)} will be sent to ${wallet.defaultMethodSummary}. The Vakil team processes payouts.'),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Request'))],
    ));
    if (ok != true) return;
    setState(() => _requesting = true);
    try {
      await wallet.requestWithdrawal();
      if (mounted) toast(context, 'Payout requested');
    } on PartnerNetworkException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final w = context.watch<WalletController>();
    final month = _months[DateTime.now().month - 1];
    final total = w.monthChat + w.monthVoice;
    final canPay = w.availableBalance > 0 && w.availableBalance >= w.minimumWithdrawal;

    return RefreshIndicator(
      color: c.brand,
      onRefresh: w.load,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 120), children: [
        Text('Earnings', style: sora(28, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.nav, borderRadius: BorderRadius.circular(22)),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -60, top: -60, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 28)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('READY FOR PAYOUT', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 6),
              Text(inr(w.availableBalance), style: sora(34, weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                w.pendingPayouts > 0 ? '${inr(w.pendingPayouts)} already requested · to ${w.defaultMethodSummary}'
                    : (w.hasUpi || w.hasBank) ? 'Payouts go to ${w.defaultMethodSummary}' : 'Add a UPI ID or bank account to get paid',
                style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75)),
              ),
              if (w.minimumWithdrawal > 0 && w.availableBalance < w.minimumWithdrawal)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Minimum payout is ${inr(w.minimumWithdrawal)}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: LtButton('Request payout', kind: BtnKind.gold, loading: _requesting, onTap: canPay ? () => _requestPayout(w) : null)),
                const SizedBox(width: 10),
                SizedBox(height: 46, child: TextButton(
                  style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutMethodsScreen())),
                  child: const Text('Payout account', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
              ]),
            ]),
          ]),
        ),
        SecHead('$month by mode', trailing: Text('${inr(w.monthNet)} net', style: TextStyle(fontSize: 12, color: c.muted))),
        LtCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(height: 10, child: total <= 0
                ? Container(color: c.surface2)
                : Row(children: [
                    if (w.monthChat > 0) Expanded(flex: (w.monthChat * 100).round(), child: Container(color: c.brand)),
                    if (w.monthChat > 0 && w.monthVoice > 0) const SizedBox(width: 2),
                    if (w.monthVoice > 0) Expanded(flex: (w.monthVoice * 100).round(), child: Container(color: c.gold)),
                  ])),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 14, children: [_legend(c, c.brand, 'Chat ${inr(w.monthChat)}'), _legend(c, c.gold, 'Voice ${inr(w.monthVoice)}')]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _kv(c, 'Clients paid', inr(w.monthGross)),
              const SizedBox(height: 6),
              _kv(c, 'Platform fee${w.commissionPercent > 0 ? ' (${w.commissionPercent % 1 == 0 ? w.commissionPercent.toInt() : w.commissionPercent}%)' : ''}', '−${inr(w.monthCommission)}'),
              const SizedBox(height: 6),
              _kv(c, 'You keep', inr(w.monthNet), strong: true),
            ]),
          ),
        ])),
        SecHead('Ledger', action: w.transactions.length > 8 ? 'See all' : null, onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletHistoryScreen()))),
        if (w.transactions.isEmpty)
          const EmptyCard(icon: Icons.account_balance_wallet_outlined, title: 'No earnings yet', text: 'Each finished consultation shows here with what the client paid.')
        else
          LtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
            for (var i = 0; i < w.transactions.length && i < 8; i++)
              LtRow(
                first: i == 0,
                leading: Initials('', icon: w.transactions[i].isCredit ? Icons.account_balance_wallet_outlined : Icons.account_balance_outlined, iconBg: c.surface2, iconColor: c.ink),
                title: w.transactions[i].title,
                subtitle: '${w.transactions[i].subtitle} · ${dayLabel(w.transactions[i].date)}',
                trailing: Text('${w.transactions[i].isCredit ? '+' : ''}${inr(w.transactions[i].amount)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: w.transactions[i].isCredit ? c.good : c.ink)),
              ),
          ])),
      ]),
    );
  }

  Widget _legend(LT c, Color color, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: c.ink)),
      ]);

  Widget _kv(LT c, String k, String v, {bool strong = false}) => Row(children: [
        Expanded(child: Text(k, style: TextStyle(fontSize: 12.5, color: strong ? c.ink : c.muted))),
        Text(v, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: strong ? c.good : c.ink)),
      ]);
}
