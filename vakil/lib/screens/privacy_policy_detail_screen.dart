import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';

class _Section {
  const _Section(this.icon, this.background, this.foreground, this.title,
      this.body);
  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String body;
}

final _sections = [
  _Section(
    Icons.storage_outlined,
    AppColors.blueSoft,
    AppColors.blueAccent,
    'Data Collection',
    'We collect information you provide directly, such as your name, email, and profile details. We also automatically collect device and usage data to improve performance.',
  ),
  _Section(
    Icons.settings_outlined,
    AppColors.greenAccent.withValues(alpha: 0.15),
    AppColors.greenAccent,
    'How We Use It',
    'Your data is used to provide, maintain, and improve our services, communicate with you about updates, and detect fraudulent activity.',
  ),
  _Section(
    Icons.share_outlined,
    AppColors.amberSoft,
    AppColors.amber,
    'Information Sharing',
    'We do not sell your personal data. We only share information with trusted third-party providers who perform services on our behalf under strict confidentiality agreements.',
  ),
  _Section(
    Icons.shield_outlined,
    AppColors.purpleAccent.withValues(alpha: 0.15),
    AppColors.purpleAccent,
    'Security Measures',
    'We implement industry-standard encryption and security measures to protect your data from unauthorized access, alteration, or disclosure.',
  ),
];

class PrivacyPolicyDetailScreen extends StatelessWidget {
  const PrivacyPolicyDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textDark),
                  ),
                  Expanded(
                    child: Text('Privacy Policy',
                        textAlign: TextAlign.center,
                        style: AppText.h3(AppColors.textDark)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How we handle your data',
                        style: AppText.h2(AppColors.textDark)),
                    const SizedBox(height: 8),
                    Text(
                      'We value your privacy. This policy explains how we '
                      'collect, use, and protect your information when you '
                      'use our services. Last updated: Oct 24, 2023.',
                      style: AppText.bodySmall(AppColors.textGray),
                    ),
                    const SizedBox(height: 20),
                    for (final section in _sections) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconChip(
                            icon: section.icon,
                            background: section.background,
                            foreground: section.foreground,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(section.title,
                                    style:
                                        AppText.bodyMedium(AppColors.textDark)),
                                const SizedBox(height: 4),
                                Text(section.body,
                                    style:
                                        AppText.bodySmall(AppColors.textGray)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SolidButton(
                label: 'I Agree',
                background: Colors.black,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
