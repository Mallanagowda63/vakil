import 'package:flutter/material.dart';
import '../screens/wallet_screen.dart';
import '../state/free_trial_state.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';

/// "₹12/min", or "₹12.50/min" when the rate has paise.
String formatRate(double rate) => '${rate == rate.roundToDouble() ? formatCurrencyWhole(rate) : formatCurrency(rate)}/min';

/// "₹250" for the top bar (paise only when there are some).
String formatBalance(double value) => value == value.roundToDouble() ? formatCurrencyWhole(value) : formatCurrency(value);

/// Opens the Wallet screen, optionally explaining why (e.g. not enough balance).
Future<void> openWallet(BuildContext context, {String? message}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WalletScreen(message: message)));

/// Top-bar button with the live wallet balance; opens the Wallet screen.
class WalletButton extends StatelessWidget {
  const WalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: WalletState.balanceListenable,
      builder: (context, balance, _) => Material(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openWallet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.blueAccent),
              const SizedBox(width: 5),
              Text(formatBalance(balance), style: AppText.bodyMedium(AppColors.blueAccent).copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "FREE 1 min trial" until the trial is used, then the lawyer's price.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.ratePerMinute, this.large = false});
  final double ratePerMinute;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FreeTrialState.listenable,
      builder: (context, trialUsed, _) {
        final free = !trialUsed;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
          decoration: BoxDecoration(color: free ? const Color(0xFFE6F7EE) : AppColors.goldSoft, borderRadius: BorderRadius.circular(20)),
          child: Text(
            free ? 'FREE 1 min trial' : formatRate(ratePerMinute),
            style: (large ? AppText.bodyMedium : AppText.caption)(free ? AppColors.greenAccent : AppColors.paidBadgeFg).copyWith(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}
