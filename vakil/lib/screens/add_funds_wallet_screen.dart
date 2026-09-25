import 'package:flutter/material.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/app_widgets.dart';
import 'payment_info_screen.dart';

class AddFundsWalletScreen extends StatefulWidget {
  const AddFundsWalletScreen({super.key});

  @override
  State<AddFundsWalletScreen> createState() => _AddFundsWalletScreenState();
}

class _AddFundsWalletScreenState extends State<AddFundsWalletScreen> {
  int _selectedAmount = 1; // index into _amounts, ₹200 pre-selected
  int _selectedMethod = 0; // Google Pay / UPI pre-selected

  final _amounts = const ['₹100', '₹200', '₹500'];

  final _methods = const [
    _PaymentMethod(
      title: 'Google Pay / UPI',
      subtitle: 'Pay instantly using your default UPI ID',
    ),
    _PaymentMethod(
      title: 'UPI ID',
      subtitle: 'Pay using any bank-linked UPI ID',
    ),
    _PaymentMethod(
      title: 'PhonePe',
      subtitle: 'Pay using your PhonePe account',
    ),
    _PaymentMethod(
      title: 'Saved Debit Card',
      subtitle: 'HDFC Bank •••• 8840',
    ),
    _PaymentMethod(
      title: 'Net Banking',
      subtitle: 'All major domestic banks available',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textDark),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text('Add Funds to Wallet',
                      style: AppText.h3(AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightStroke),
                ),
                child: ValueListenableBuilder<double>(
                  valueListenable: WalletState.balanceListenable,
                  builder: (context, balance, _) {
                    final low = balance <= 0;
                    final color =
                        low ? AppColors.redAccent : AppColors.greenAccent;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FieldLabel('CURRENT WALLET BALANCE'),
                              const SizedBox(height: 6),
                              Text(formatCurrency(balance),
                                  style: AppText.h1(AppColors.textDark)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(low ? 'LOW BALANCE' : 'ACTIVE',
                              style: AppText.label(color)),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              FieldLabel('SELECT TOP-UP AMOUNT'),
              const SizedBox(height: 10),
              Row(
                children: List.generate(_amounts.length, (i) {
                  final selected = _selectedAmount == i;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i == _amounts.length - 1 ? 0 : 10),
                      child: _AmountChip(
                        label: _amounts[i],
                        selected: selected,
                        onTap: () => setState(() => _selectedAmount = i),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              _AmountChip(
                label: '₹ 1,000',
                selected: _selectedAmount == 3,
                fullWidth: true,
                badge: 'POPULAR',
                onTap: () => setState(() => _selectedAmount = 3),
              ),
              const SizedBox(height: 24),
              FieldLabel('CHOOSE PAYMENT METHOD'),
              const SizedBox(height: 10),
              ...List.generate(_methods.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PaymentMethodRow(
                    method: _methods[i],
                    selected: _selectedMethod == i,
                    onTap: () => setState(() => _selectedMethod = i),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SolidButton(
                label: _amountLabel(),
                background: Colors.black,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentInfoScreen(
                        amount: _selectedAmountValue(),
                        paymentMethodLabel: _methods[_selectedMethod].title,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('Cancel & Go Back',
                      style: AppText.body(AppColors.textGray)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _amountValues = [100, 200, 500, 1000];

  int _selectedAmountValue() => _amountValues[_selectedAmount];

  String _amountLabel() {
    const labels = ['100', '200', '500', '1,000'];
    return 'Add ₹${labels[_selectedAmount]} to Wallet';
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.amber : AppColors.lightStroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppText.bodyMedium(
                selected ? AppColors.amber : AppColors.textDark,
              ),
            ),
            if (badge != null) ...[
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: AppText.caption(AppColors.gold)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod {
  const _PaymentMethod({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final _PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.textDark : AppColors.lightStroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.credit_card, size: 18, color: AppColors.textGray),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.title,
                      style: AppText.bodyMedium(AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(method.subtitle,
                      style: AppText.bodySmall(AppColors.textGray)),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? AppColors.textDark : AppColors.lightStroke,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.textDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
