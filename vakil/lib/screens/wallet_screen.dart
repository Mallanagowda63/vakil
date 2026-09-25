import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';

/// Wallet: current balance, recharge (preset amounts or a custom amount,
/// paid through Razorpay), and the transaction history.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.message});
  /// Why the wallet was opened, e.g. "Add money to chat with this lawyer".
  final String? message;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _wallet = WalletService.instance;
  final _custom = TextEditingController();
  int? _preset;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_changed);
    _wallet.refresh();
  }

  @override
  void dispose() {
    _wallet.removeListener(_changed);
    _custom.dispose();
    super.dispose();
  }

  void _changed() { if (mounted) setState(() {}); }

  double? get _amount => _custom.text.trim().isNotEmpty ? double.tryParse(_custom.text.trim()) : _preset?.toDouble();

  Future<void> _recharge() async {
    final amount = _amount;
    final messenger = ScaffoldMessenger.of(context);
    if (amount == null || amount < _wallet.minRecharge || amount > _wallet.maxRecharge) {
      messenger.showSnackBar(SnackBar(content: Text('Enter an amount between ${formatCurrencyWhole(_wallet.minRecharge)} and ${formatCurrencyWhole(_wallet.maxRecharge)}')));
      return;
    }
    setState(() => _paying = true);
    try {
      final added = await _wallet.recharge(amount);
      if (!mounted) return;
      _custom.clear();
      setState(() => _preset = null);
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.greenAccent, content: Text('${formatCurrency(added)} added to wallet')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = _wallet.loaded && _wallet.paymentMode == 'unavailable';
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(title: Text('Wallet', style: AppText.h3(AppColors.textDark)), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _wallet.refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.message != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [const Icon(Icons.info_outline, color: AppColors.amber, size: 20), const SizedBox(width: 10), Expanded(child: Text(widget.message!, style: AppText.bodyMedium(AppColors.textDark)))]),
            ),
            const SizedBox(height: 14),
          ],
          // Balance
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.aiCardStart, AppColors.aiCardEnd]), borderRadius: BorderRadius.circular(18)),
            child: ValueListenableBuilder<double>(
              valueListenable: WalletState.balanceListenable,
              builder: (_, balance, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current balance', style: AppText.bodySmall(Colors.white70)),
                const SizedBox(height: 6),
                Text(formatCurrency(balance), style: AppText.h1(Colors.white)),
                const SizedBox(height: 4),
                Text('Used for chats and calls after your free trial, charged per minute.', style: AppText.caption(Colors.white70)),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          Text('Recharge', style: AppText.h3(AppColors.textDark)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: _wallet.rechargeOptions.map((amount) {
            final selected = _preset == amount && _custom.text.trim().isEmpty;
            return ChoiceChip(
              label: Text(formatCurrencyWhole(amount)),
              selected: selected,
              onSelected: _paying ? null : (_) { _custom.clear(); setState(() => _preset = amount); },
              labelStyle: AppText.bodyMedium(selected ? Colors.white : AppColors.textDark),
              selectedColor: AppColors.blueAccent,
              backgroundColor: AppColors.lightSurface,
              showCheckmark: false,
            );
          }).toList()),
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            enabled: !_paying,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?'))],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Custom amount',
              prefixText: '₹ ',
              filled: true,
              fillColor: AppColors.lightSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _paying || unavailable || _amount == null ? null : _recharge,
              style: FilledButton.styleFrom(backgroundColor: AppColors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _paying
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_amount == null ? 'Recharge' : 'Recharge ${formatCurrency(_amount!)}', style: AppText.button(Colors.white)),
            ),
          ),
          if (unavailable) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Recharge is not available yet. Please try again later.', style: AppText.caption(AppColors.redAccent))),
          if (_wallet.paymentMode == 'test') Padding(padding: const EdgeInsets.only(top: 8), child: Text('Test mode: no real payment is taken.', style: AppText.caption(AppColors.textGray))),
          const SizedBox(height: 26),
          Text('Transaction history', style: AppText.h3(AppColors.textDark)),
          const SizedBox(height: 6),
          if (!_wallet.loaded) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_wallet.transactions.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No transactions yet.', style: AppText.body(AppColors.textGray))))
          else ..._wallet.transactions.map((t) => _TransactionRow(t)),
        ]),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.t);
  final WalletTransaction t;

  String get _title => switch (t.reason) {
        'recharge' => 'Wallet recharge',
        'chat' => 'Chat',
        'call' => 'Voice call',
        'refund' => 'Refund',
        _ => t.isDebit ? 'Payment' : 'Credit',
      };

  @override
  Widget build(BuildContext context) {
    final color = t.isDebit ? AppColors.redAccent : AppColors.greenAccent;
    final when = t.createdAt == null ? '' : '${t.createdAt!.day.toString().padLeft(2, '0')}/${t.createdAt!.month.toString().padLeft(2, '0')} ${t.createdAt!.hour.toString().padLeft(2, '0')}:${t.createdAt!.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lightStroke))),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: .12), child: Icon(t.isDebit ? Icons.north_east : Icons.south_west, size: 16, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, style: AppText.bodyMedium(AppColors.textDark)),
          Text([if (t.note.isNotEmpty) t.note, when].join(' · '), style: AppText.caption(AppColors.textGray), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${t.isDebit ? '−' : '+'}${formatCurrency(t.amount)}', style: AppText.bodyMedium(color).copyWith(fontWeight: FontWeight.w700)),
          Text('Bal ${formatCurrency(t.balanceAfter)}', style: AppText.caption(AppColors.textGray)),
        ]),
      ]),
    );
  }
}
