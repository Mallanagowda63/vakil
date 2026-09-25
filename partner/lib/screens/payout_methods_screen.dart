import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_data.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'connect_upi_screen.dart';
import 'link_bank_account_screen.dart';

class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  late PayoutMethodType? _selected = context.read<WalletController>().defaultMethod;

  void _continueWithSelected() {
    if (_selected == null) return;
    final wallet = context.read<WalletController>();
    wallet.setDefaultMethod(_selected!);
    wallet.enableAutoSettlement();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Automatic weekly settlements enabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Payout Methods')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Settlement Option', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose how you want your earned fees and consultation payouts to be deposited automatically.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (wallet.hasUpi)
                      _methodCard(
                        icon: Icons.qr_code_2,
                        title: 'Unified Payments Interface (UPI)',
                        subtitle: 'Instant settlement, 24/7',
                        connectedLabel: 'Currently Connected: ${wallet.upiId}',
                        selected: _selected == PayoutMethodType.upi,
                        isDefault: wallet.defaultMethod == PayoutMethodType.upi,
                        onTap: () => setState(() => _selected = PayoutMethodType.upi),
                      ),
                    if (wallet.hasBank)
                      _methodCard(
                        icon: Icons.account_balance_outlined,
                        title: 'Bank Account Transfer',
                        subtitle: 'IMPS/NEFT, settled next business day',
                        connectedLabel: 'Currently Connected: HDFC Bank ****${wallet.bankAccountLast4}',
                        selected: _selected == PayoutMethodType.bank,
                        isDefault: wallet.defaultMethod == PayoutMethodType.bank,
                        onTap: () => setState(() => _selected = PayoutMethodType.bank),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Continue with Selected',
                    onPressed: _selected == null ? null : _continueWithSelected,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ConnectUpiScreen()),
                            );
                            if (mounted) setState(() => _selected = PayoutMethodType.upi);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New UPI ID'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LinkBankAccountScreen()),
                            );
                            if (mounted) setState(() => _selected = PayoutMethodType.bank);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Bank A/C'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String connectedLabel,
    required bool selected,
    required bool isDefault,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(connectedLabel, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE6F7EE), borderRadius: BorderRadius.circular(20)),
                    child: const Text('DEFAULT', style: TextStyle(color: AppColors.success, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
