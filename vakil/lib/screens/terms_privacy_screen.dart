import 'package:flutter/material.dart';
import '../services/terms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';
import 'privacy_policy_detail_screen.dart';
import 'splash_screen.dart';
import 'terms_of_service_detail_screen.dart';

/// The very first thing the app shows on a fresh install — gates entry
/// into the signup/login flow behind Terms & Privacy consent. Once
/// agreed, this is skipped on every future launch.
class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({super.key});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen> {
  bool _checking = true;
  bool _agree = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await TermsService.load();
    if (!mounted) return;
    if (TermsService.agreed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
      return;
    }
    setState(() => _checking = false);
  }

  Future<void> _openTerms() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TermsOfServiceDetailScreen()),
    );
    if (result == true) setState(() => _agree = true);
  }

  Future<void> _openPrivacy() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyDetailScreen()),
    );
    if (result == true) setState(() => _agree = true);
  }

  Future<void> _continue() async {
    if (!_agree) return;
    await TermsService.setAgreed();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(backgroundColor: AppColors.lightBg);
    }

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Terms & Privacy', style: AppText.h1(AppColors.textDark)),
              const SizedBox(height: 8),
              Text(
                'Please review the information below before continuing.',
                style: AppText.body(AppColors.textGray),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Terms of Service',
                        style: AppText.bodyMedium(AppColors.textDark)),
                    const SizedBox(height: 6),
                    Text(
                      'These terms describe how you may use the app, your '
                      'responsibilities as a user, and the rules that apply '
                      'to your account and activity.',
                      style: AppText.bodySmall(AppColors.textGray),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openTerms,
                      child: Text('Read the full Terms of Service',
                          style: AppText.bodySmall(AppColors.blueAccent)
                              .copyWith(
                                  decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.lightStroke),
                    const SizedBox(height: 16),
                    Text('Privacy Policy',
                        style: AppText.bodyMedium(AppColors.textDark)),
                    const SizedBox(height: 6),
                    Text(
                      'Our privacy policy explains what information we '
                      'collect, why we collect it, how it is used, and the '
                      'choices available to you.',
                      style: AppText.bodySmall(AppColors.textGray),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openPrivacy,
                      child: Text('Read the full Privacy Policy',
                          style: AppText.bodySmall(AppColors.blueAccent)
                              .copyWith(
                                  decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _agree = !_agree),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: _agree ? AppColors.blueAccent : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agree
                              ? AppColors.blueAccent
                              : AppColors.lightStroke,
                          width: 1.5,
                        ),
                      ),
                      child: _agree
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I have read and agree to the Terms of Service and '
                        'acknowledge the Privacy Policy',
                        style: AppText.bodySmall(AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SolidButton(
                label: 'I Agree',
                background:
                    _agree ? AppColors.blueAccent : AppColors.lightStroke,
                foreground: _agree ? Colors.white : AppColors.textGraySoft,
                onTap: _agree ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
