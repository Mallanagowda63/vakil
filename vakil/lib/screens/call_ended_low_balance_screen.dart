import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/app_widgets.dart';
import 'home_shell.dart';
import 'reconnect_wallet_screen.dart';

class CallEndedLowBalanceScreen extends StatelessWidget {
  const CallEndedLowBalanceScreen({
    super.key,
    required this.lawyer,
    required this.elapsedSeconds,
    required this.totalDeducted,
    required this.isVoiceCall,
  });

  final Lawyer lawyer;
  final int elapsedSeconds;
  final double totalDeducted;
  final bool isVoiceCall;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Call Disconnected',
                        style: AppText.h3(AppColors.textDark)),
                  ),
                  Icon(Icons.more_vert, size: 18, color: AppColors.textGray),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Low Balance Disconnection',
                              style: AppText.bodyMedium(AppColors.textDark)),
                          const SizedBox(height: 3),
                          Text(
                            'Your call ended because your wallet balance fell to ₹0.00.',
                            style: AppText.bodySmall(AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightStroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel('UNFINISHED CONSULTATION'),
                    const SizedBox(height: 12),
                    _Row('Advisor', lawyer.name),
                    const SizedBox(height: 8),
                    _Row('Elapsed Time', formatMinutesSeconds(elapsedSeconds)),
                    const SizedBox(height: 8),
                    _Row('Total Deducted', formatCurrency(totalDeducted),
                        valueColor: AppColors.amber),
                    const SizedBox(height: 10),
                    Divider(color: AppColors.lightStroke),
                    const SizedBox(height: 8),
                    _Row('Remaining Balance', '₹0.00', bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your call will reconnect automatically. Add funds now and '
                'your consultation with ${lawyer.name} will reconnect '
                'automatically as soon as payment succeeds. The line is '
                'being held for the next 4 minutes.',
                style: AppText.bodySmall(AppColors.textGray),
              ),
              const Spacer(),
              SolidButton(
                label: 'Add Funds to Reconnect',
                background: AppColors.blueAccent,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReconnectWalletScreen(
                        lawyer: lawyer,
                        isVoiceCall: isVoiceCall,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              OutlineButton(
                label: 'Back to Dashboard',
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeShell()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.bodySmall(AppColors.textGray)),
        Text(value,
            style: bold
                ? AppText.h3(AppColors.textDark)
                : AppText.bodyMedium(valueColor ?? AppColors.textDark)),
      ],
    );
  }
}
