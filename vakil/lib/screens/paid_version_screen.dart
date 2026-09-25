import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';
import 'add_funds_wallet_screen.dart';

class PaidVersionScreen extends StatefulWidget {
  const PaidVersionScreen({super.key});

  @override
  State<PaidVersionScreen> createState() => _PaidVersionScreenState();
}

class _PaidVersionScreenState extends State<PaidVersionScreen> {
  int _selectedPlan = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.access_time_filled,
                      size: 28, color: AppColors.textGray),
                ),
              ),
              const SizedBox(height: 18),
              Text('Free Session Completed',
                  textAlign: TextAlign.center,
                  style: AppText.h1(AppColors.textDark)),
              const SizedBox(height: 8),
              Text(
                'Your 1-hour introductory legal chat has ended. '
                'Upgrade to continue with your expert attorney.',
                textAlign: TextAlign.center,
                style: AppText.body(AppColors.textGray),
              ),
              const SizedBox(height: 26),
              Text('UNLOCK PREMIUM LEGAL PROTECTION',
                  style: AppText.label(AppColors.textGraySoft)),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.headset_mic_outlined,
                iconBg: AppColors.amberSoft,
                iconFg: AppColors.amber,
                title: 'Continuous Direct Consultations',
                description:
                    'Keep chatting with attorney Sarah Jenkins without any sudden interruption or time limits.',
              ),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.folder_shared_outlined,
                iconBg: AppColors.goldSoft,
                iconFg: AppColors.gold,
                title: 'Secure Document Sharing',
                description:
                    'Instantly upload contracts, notices, or legal files for on-off case reviews during consultations.',
              ),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.verified_outlined,
                iconBg: AppColors.amberSoft,
                iconFg: AppColors.amber,
                title: 'Verified Court-Ready Templates',
                description:
                    'Get free access to hundreds of vetted state-specific NDAs, agreements, and notices.',
              ),
              const SizedBox(height: 26),
              _PlanCard(
                selected: _selectedPlan == 0,
                onTap: () => setState(() => _selectedPlan = 0),
                title: 'Base Plan',
                badge: 'SAVE 50%',
                subtitle: 'Billed as ₹109/5min',
                price: '₹49.00',
                priceSuffix: '/min',
              ),
              const SizedBox(height: 12),
              _PlanCard(
                selected: _selectedPlan == 1,
                onTap: () => setState(() => _selectedPlan = 1),
                title: 'Prime Plan',
                subtitle: 'Cancel anytime. Flexible protection.',
                price: '₹139.99',
                priceSuffix: '/hr',
              ),
              const SizedBox(height: 24),
              SolidButton(
                label: 'Unlock Unlimited Access',
                background: Colors.black,
                icon: Icons.arrow_forward,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddFundsWalletScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('Dismiss & Return to Home',
                      style: AppText.body(AppColors.textGray)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconChip(icon: icon, background: iconBg, foreground: iconFg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.bodyMedium(AppColors.textDark)),
              const SizedBox(height: 3),
              Text(description,
                  style: AppText.bodySmall(AppColors.textGray)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceSuffix,
    this.badge,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? badge;
  final String subtitle;
  final String price;
  final String priceSuffix;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.lightStroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.lightStroke,
                  width: 2,
                ),
                color: selected ? AppColors.gold : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: AppText.bodyMedium(AppColors.textDark)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: AppText.caption(Colors.white)
                                  .copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppText.bodySmall(AppColors.textGray)),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: price, style: AppText.h3(AppColors.textDark)),
                  TextSpan(
                      text: priceSuffix,
                      style: AppText.bodySmall(AppColors.textGray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
