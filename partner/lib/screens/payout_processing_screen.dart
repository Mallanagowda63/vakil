import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/wallet_data.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class PayoutProcessingScreen extends StatelessWidget {
  final WalletTransaction transaction;
  const PayoutProcessingScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isUpi = transaction.subtitle.contains('UPI');

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
                  const Text('Vakil Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE6F7EE), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 11, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('SECURE', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(color: AppColors.infoBg, shape: BoxShape.circle),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Payout Processing', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Your payout is processing. It will reach your account soon. Thank you for your request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _timelineRow(
                icon: Icons.check_circle,
                iconColor: AppColors.success,
                title: 'Payout Request Received',
                subtitle: 'Verified on ${DateFormat('MMM d, h:mm a').format(transaction.date)}',
              ),
              _timelineRow(
                icon: Icons.autorenew,
                iconColor: AppColors.primary,
                title: 'Processing Settlements',
                subtitle: 'Securely clearing with NPCI node',
              ),
              _timelineRow(
                icon: Icons.circle,
                iconColor: AppColors.textSecondary,
                title: 'Estimated Arrival',
                subtitle: isUpi ? 'Transfer completes within 2 hours' : 'Transfer completes by next business day',
                isLast: true,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TRANSACTION DETAILS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.4)),
                    const SizedBox(height: 12),
                    _row('Payout Amount', '₹${NumberFormat('#,##,##0.00', 'en_IN').format(transaction.amount.abs())}'),
                    _row('Settlement Type', isUpi ? 'UPI Instant Settlement' : 'Bank Transfer (IMPS/NEFT)'),
                    _row('Transfer Account', transaction.subtitle.replaceAll(RegExp(r'Settl(ing|ed) (via|to) '), '')),
                    _row('Reference ID', transaction.id),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5DCC0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB5751B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Funds usually settle within minutes. Check your UPI app.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB5751B), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: 'Return to Wallet', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 18, color: iconColor),
              if (!isLast) Expanded(child: Container(width: 1.5, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
