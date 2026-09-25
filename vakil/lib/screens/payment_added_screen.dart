import 'package:flutter/material.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/app_widgets.dart';
import 'splash_returning_screen.dart';

class PaymentAddedScreen extends StatefulWidget {
  const PaymentAddedScreen({super.key, this.walletTopUp});

  /// When set, this amount is credited to [WalletState.balance] once —
  /// keeps the wallet screens and the call-billing flow agreeing on the
  /// same number.
  final double? walletTopUp;

  @override
  State<PaymentAddedScreen> createState() => _PaymentAddedScreenState();
}

class _PaymentAddedScreenState extends State<PaymentAddedScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.walletTopUp != null) {
      WalletState.balance += widget.walletTopUp!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWalletTopUp = widget.walletTopUp != null;

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payments',
                  style: AppText.bodySmall(AppColors.textGray)),
              const SizedBox(height: 6),
              Text('Payment added', style: AppText.h1(AppColors.textDark)),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Payment added\nsuccessfully',
                          textAlign: TextAlign.center,
                          style: AppText.h2(AppColors.textDark),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isWalletTopUp
                              ? '${formatCurrency(widget.walletTopUp!)} has been added to your wallet. '
                                  'New balance: ${formatCurrency(WalletState.balance)}.'
                              : 'Your Visa card ending in 4242 has been saved '
                                  'securely and is ready for your next purchase.',
                          textAlign: TextAlign.center,
                          style: AppText.bodySmall(AppColors.textGray),
                        ),
                        const SizedBox(height: 22),
                        SolidButton(
                          label: 'Done',
                          background: AppColors.textDark,
                          height: 50,
                          onTap: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const SplashReturningScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlineButton(
                          label: 'View payment methods',
                          background: Colors.white,
                          foreground: AppColors.textDark,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'You can update or remove this payment method anytime.',
                  textAlign: TextAlign.center,
                  style: AppText.caption(AppColors.textGraySoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
