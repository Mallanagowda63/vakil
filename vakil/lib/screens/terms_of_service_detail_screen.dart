import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const _sections = [
  _Section('1. Acceptance of Terms',
      'By accessing or using our services, you agree to be bound by these Terms. If you do not agree, do not use the service.'),
  _Section('2. Account Responsibilities',
      'You are responsible for safeguarding your password and for all activities that occur under your account.'),
  _Section('3. Acceptable Use',
      'You may use the service only for lawful purposes and in accordance with these Terms and all applicable laws.'),
  _Section('4. Prohibited Conduct',
      'You agree not to engage in any fraudulent activity, harassment, or attempts to reverse engineer the service.'),
  _Section('5. Content and Privacy',
      'Your use of the service is also governed by our Privacy Policy. You retain rights to your content but grant us a license to use it.'),
  _Section('6. Service Changes',
      'We reserve the right to modify or discontinue the service at any time without notice.'),
  _Section('7. Termination',
      'We may terminate or suspend your account immediately, without prior notice or liability, for any reason.'),
  _Section('8. Limitation of Liability',
      'To the maximum extent permitted by law, we shall not be liable for any indirect or consequential damages.'),
  _Section('9. Contact Us',
      'If you have any questions about these Terms, please contact us at support@example.com.'),
];

class TermsOfServiceDetailScreen extends StatelessWidget {
  const TermsOfServiceDetailScreen({super.key});

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
                    child: Text('Terms of Service',
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
                    Text('Please read carefully',
                        style: AppText.h2(AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text('Last updated: October 24, 2023',
                        style: AppText.bodySmall(AppColors.textGray)),
                    const SizedBox(height: 18),
                    for (final section in _sections) ...[
                      Text(section.title,
                          style: AppText.bodyMedium(AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(section.body,
                          style: AppText.bodySmall(AppColors.textGray)),
                      const SizedBox(height: 16),
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
