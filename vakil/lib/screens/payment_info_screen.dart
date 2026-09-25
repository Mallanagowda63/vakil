import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/app_widgets.dart';
import 'payment_added_screen.dart';

const _couponDiscount = 150.0;
const _gstRate = 0.18;

class PaymentInfoScreen extends StatefulWidget {
  const PaymentInfoScreen({
    super.key,
    required this.amount,
    required this.paymentMethodLabel,
  });

  final int amount;
  final String paymentMethodLabel;

  @override
  State<PaymentInfoScreen> createState() => _PaymentInfoScreenState();
}

class _PaymentInfoScreenState extends State<PaymentInfoScreen> {
  bool _couponApplied = true;

  double get _subtotal => widget.amount.toDouble();
  double get _gst => _subtotal * _gstRate;
  double get _discount => _couponApplied ? _couponDiscount : 0;
  double get _total => _subtotal + _gst - _discount;

  void _toggleCoupon() {
    setState(() => _couponApplied = !_couponApplied);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_couponApplied
            ? 'Coupon LEGAL150 applied'
            : 'Coupon removed'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                  Expanded(
                    child: Text('Secure Checkout',
                        style: AppText.h3(AppColors.textDark)),
                  ),
                  Icon(Icons.help_outline,
                      size: 20, color: AppColors.textGray),
                ],
              ),
              const SizedBox(height: 22),
              FieldLabel('BILLING SUMMARY'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightStroke),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Subtotal',
                      value: formatCurrency(_subtotal),
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'GST (18%)',
                      value: formatCurrency(_gst),
                    ),
                    if (_couponApplied) ...[
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Coupon Discount',
                        value: '-${formatCurrency(_discount)}',
                        valueColor: AppColors.greenAccent,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Divider(color: AppColors.lightStroke),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Amount',
                                  style:
                                      AppText.bodyMedium(AppColors.textDark)),
                              const SizedBox(height: 2),
                              Text('Inclusive of all taxes & fees',
                                  style: AppText.caption(AppColors.textGray)),
                            ],
                          ),
                        ),
                        Text(formatCurrency(_total),
                            style: AppText.h2(AppColors.textDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 13, color: AppColors.textGraySoft),
                  const SizedBox(width: 5),
                  Text(
                    'Secured with bank-grade 256-bit SSL encryption',
                    style: AppText.caption(AppColors.textGraySoft),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FieldLabel('APPLY COUPON CODE'),
                  if (_couponApplied)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.greenAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Offer active',
                          style: AppText.caption(AppColors.greenAccent)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _toggleCoupon,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      IconChip(
                        icon: Icons.sell_outlined,
                        background: Colors.white,
                        foreground: AppColors.gold,
                        size: 36,
                        iconSize: 17,
                        radius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXCLUSIVE OFFER',
                                style: AppText.label(AppColors.gold)),
                            const SizedBox(height: 2),
                            Text('LEGAL150',
                                style:
                                    AppText.bodyMedium(AppColors.textDark)),
                          ],
                        ),
                      ),
                      if (_couponApplied)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.greenAccent
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Applied (-${formatCurrency(_discount)})',
                            style: AppText.caption(AppColors.greenAccent)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        )
                      else
                        Text('Apply',
                            style: AppText.bodyMedium(AppColors.blueAccent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SolidButton(
                label: 'Proceed to Pay',
                background: Colors.black,
                icon: Icons.arrow_forward,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentAddedScreen(
                        walletTopUp: widget.amount.toDouble(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 13, color: AppColors.textGraySoft),
                  const SizedBox(width: 4),
                  Text('Verified Partner',
                      style: AppText.caption(AppColors.textGraySoft)),
                  const SizedBox(width: 10),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.textGraySoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.security, size: 13, color: AppColors.textGraySoft),
                  const SizedBox(width: 4),
                  Text('Payments Secured',
                      style: AppText.caption(AppColors.textGraySoft)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.bodySmall(AppColors.textGray)),
        Text(value,
            style: AppText.bodyMedium(valueColor ?? AppColors.textDark)),
      ],
    );
  }
}
