import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/profile_data.dart';
import '../models/wallet_data.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'payout_methods_screen.dart';
import 'payout_processing_screen.dart';
import 'wallet_history_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  Future<void> _withdraw(BuildContext context) async {
    final wallet = context.read<WalletController>();
    if (wallet.availableBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available balance to withdraw right now.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw money?'),
        content: Text(
          'Withdraw ₹${_Money.format(wallet.availableBalance)} to ${wallet.defaultMethodSummary}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final WalletTransaction txn;
    try {
      txn = await wallet.requestWithdrawal();
    } on PartnerNetworkException catch (e) {
      // e.g. below the minimum withdrawal set by Vakil.
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PayoutProcessingScreen(transaction: txn)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    final profile = context.watch<ProfileController>();
    final recent = wallet.transactions.take(4).toList();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Vakil Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.infoBg,
                    backgroundImage: profile.avatarImage,
                    child: profile.avatarImage == null
                        ? Text(profile.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${_Money.format(wallet.availableBalance)}',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _statColumn('Total Earnings', '₹${_Money.format(wallet.totalEarnings)}', AppColors.success),
                        ),
                        Container(width: 1, height: 30, color: Colors.white24),
                        Expanded(
                          child: _statColumn('Pending Payouts', '₹${_Money.format(wallet.pendingPayouts)}', const Color(0xFFE8B84B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Withdraw Money',
                icon: Icons.arrow_outward,
                onPressed: () => _withdraw(context),
              ),
              if (!wallet.autoSettlementEnabled) ...[
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5DCC0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB5751B)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Set Payout Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              SizedBox(height: 2),
                              Text(
                                'Connect your UPI or Bank Account to receive automatic weekly settlements.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletHistoryScreen()),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...recent.map((t) => _TransactionTile(txn: t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13.5)),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final credit = txn.isCredit;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: credit ? const Color(0xFFE6F7EE) : AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              credit ? Icons.south_west : Icons.north_east,
              size: 16,
              color: credit ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  '${txn.subtitle} · ${DateFormat('d MMM').format(txn.date)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '-'}₹${_Money.format(txn.amount.abs())}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: credit ? AppColors.success : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Money {
  const _Money();
  static String format(double value) => NumberFormat('#,##,##0.00', 'en_IN').format(value);
}
