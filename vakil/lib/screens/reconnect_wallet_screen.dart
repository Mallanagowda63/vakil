import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/app_widgets.dart';
import 'consultation_chat_screen.dart';
import 'voice_call_screen.dart';

/// A focused, single-step top-up used to resume a call that was cut off
/// for running out of balance — distinct from the general "Add Funds to
/// Wallet" screen, but shares the same [WalletState] so the balance shown
/// everywhere always agrees.
class ReconnectWalletScreen extends StatefulWidget {
  const ReconnectWalletScreen({
    super.key,
    required this.lawyer,
    required this.isVoiceCall,
  });

  final Lawyer lawyer;
  final bool isVoiceCall;

  @override
  State<ReconnectWalletScreen> createState() => _ReconnectWalletScreenState();
}

class _ReconnectWalletScreenState extends State<ReconnectWalletScreen> {
  static const _amounts = [500, 1000, 2000, 5000];
  int? _selected = 1000;
  final _customController = TextEditingController();
  bool _reconnecting = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  int get _amount {
    if (_selected != null) return _selected!;
    return int.tryParse(_customController.text.trim()) ?? 0;
  }

  void _reconnect() {
    if (_amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least ₹100')),
      );
      return;
    }

    setState(() => _reconnecting = true);
    WalletState.balance += _amount;

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final next = widget.isVoiceCall
          ? VoiceCallScreen(lawyer: widget.lawyer)
          : ConsultationChatScreen(lawyer: widget.lawyer);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    });
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
                    child: Text('Add Funds', style: AppText.h3(AppColors.textDark)),
                  ),
                  Icon(Icons.more_vert, size: 18, color: AppColors.textGray),
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
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FieldLabel('CURRENT BALANCE'),
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
                            color:
                                AppColors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Low Balance',
                              style: AppText.label(AppColors.redAccent)),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle,
                        size: 18, color: AppColors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Automatic reconnection',
                              style: AppText.bodyMedium(AppColors.textDark)),
                          const SizedBox(height: 2),
                          Text(
                            'Once payment succeeds, your call with '
                            '${widget.lawyer.name} will reconnect automatically.',
                            style: AppText.bodySmall(AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FieldLabel('SELECT TOP-UP AMOUNT'),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: _amounts.map((amt) {
                  final selected = _selected == amt;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = amt;
                      _customController.clear();
                    }),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.blueAccent
                              : AppColors.lightStroke,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(formatCurrencyWhole(amt),
                              style: AppText.bodyMedium(selected
                                  ? AppColors.blueAccent
                                  : AppColors.textDark)),
                          if (amt == 1000) ...[
                            const SizedBox(width: 6),
                            Text('Recommended',
                                style: AppText.caption(AppColors.blueAccent)),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FieldLabel('OR ENTER CUSTOM AMOUNT'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.currency_rupee,
                controller: _customController,
                hint: 'Enter amount (Min. ₹100)',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  if (v.isNotEmpty) setState(() => _selected = null);
                },
              ),
              const SizedBox(height: 22),
              FieldLabel('PAYMENT METHOD'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, size: 18, color: AppColors.textGray),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('UPI • linked account',
                          style: AppText.bodyMedium(AppColors.textDark)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Text('Change',
                          style: AppText.bodySmall(AppColors.blueAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SolidButton(
                label: _reconnecting
                    ? 'Reconnecting…'
                    : 'Add ${formatCurrency(_amount.toDouble())} & Reconnect',
                background: AppColors.blueAccent,
                onTap: _reconnecting ? null : _reconnect,
              ),
              const SizedBox(height: 10),
              Text(
                'By continuing, you authorize a deposit of '
                '${formatCurrency(_amount.toDouble())} into your wallet. '
                'Your call will reconnect automatically once payment '
                'succeeds. Unused funds can be refunded at any time.',
                textAlign: TextAlign.center,
                style: AppText.caption(AppColors.textGraySoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
