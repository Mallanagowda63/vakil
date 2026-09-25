import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/lawyer_list_tile.dart';
import 'add_funds_wallet_screen.dart';
import 'call_connecting_screen.dart';
import 'lawyer_profile_screen.dart';

class AvailableLawyersScreen extends StatefulWidget {
  const AvailableLawyersScreen({super.key});

  @override
  State<AvailableLawyersScreen> createState() =>
      _AvailableLawyersScreenState();
}

class _AvailableLawyersScreenState extends State<AvailableLawyersScreen> {
  bool _privacyMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 18, color: AppColors.textDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Privacy & Confidential Mode',
                              style:
                                  AppText.bodyMedium(AppColors.textDark)),
                          const SizedBox(height: 2),
                          Text(
                            'When enabled, your data won\'t be shared with the lawyer',
                            style: AppText.caption(AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _privacyMode,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.textDark,
                      onChanged: (v) => setState(() => _privacyMode = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.navyDeep,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: AppColors.limeAccent),
                        const SizedBox(width: 6),
                        Text('100% Cash Back!',
                            style: AppText.bodyMedium(Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Recharge your legal support',
                        style: AppText.h3(Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      'Top up before your call to get full cashback on unused minutes.',
                      style: AppText.bodySmall(
                          Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const AddFundsWalletScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.limeAccent,
                          foregroundColor: AppColors.navyDeep,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text('Recharge Now',
                            style: AppText.button(AppColors.navyDeep)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Available Lawyers',
                      style: AppText.h3(AppColors.textDark)),
                  Text('See all', style: AppText.bodySmall(AppColors.blueAccent)),
                ],
              ),
              const SizedBox(height: 12),
              ...availableLawyers.map(
                (lawyer) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LawyerListTile(
                    lawyer: lawyer,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LawyerProfileScreen(lawyer: lawyer),
                        ),
                      );
                    },
                    onChat: () =>
                        startLawyerCall(context, lawyer, isVoiceCall: false),
                    onCall: () =>
                        startLawyerCall(context, lawyer, isVoiceCall: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
