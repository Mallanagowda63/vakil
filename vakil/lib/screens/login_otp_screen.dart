import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';
import 'create_profile_screen.dart';
import 'home_shell.dart';
import 'legal_help_start_screen.dart';
import 'privacy_policy_detail_screen.dart';
import 'terms_of_service_detail_screen.dart';
import '../widgets/server_address_dialog.dart';

class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _resendTimer;
  int _resendIn = 0;
  // Set once a code has been sent; the screen then asks for the 6-digit code.
  String? _codeSentTo;
  String? _devCode;
  late final _termsTap = TapGestureRecognizer()..onTap = _openTerms;
  late final _privacyTap = TapGestureRecognizer()..onTap = _openPrivacy;

  bool _loading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _codeController.dispose();
    _resendTimer?.cancel();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsOfServiceDetailScreen()),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyDetailScreen()),
    );
  }

  /// 10-digit Indian mobile number typed by the user (+91 is added for them).
  String get _mobile {
    final digits = _mobileController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<void> _sendCode() async {
    final mobile = _mobile;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      _showSnack('Enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await AuthService.instance.requestOtp(mobile);
      if (!mounted) return;
      setState(() {
        _codeSentTo = mobile;
        // Development only: the server returns the code until SMS is connected.
        _devCode = kDebugMode ? res['devCode']?.toString() : null;
        _codeController.clear();
      });
      _startResendTimer((res['resendInSeconds'] as num?)?.toInt() ?? 30);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _continue() async {
    if (_codeSentTo == null) return _sendCode();
    final mobile = _codeSentTo!;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showSnack('Enter the 6-digit code');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyOtp(mobile, code);
      if (!mounted) return;

      final auth = AuthService.instance;
      final Widget next;
      if (!auth.profileComplete) {
        next = CreateProfileScreen(phoneNumber: '+91$mobile');
      } else if (!auth.trialUsed) {
        next = const LegalHelpStartScreen();
      } else {
        next = const HomeShell();
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (error) {
      debugPrint('Sign in failed: $error');
      _showSnack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrandCard(),
              const SizedBox(height: 28),
              Text('Sign In', style: AppText.h1(AppColors.textWhite)),
              const SizedBox(height: 6),
              Text(
                'Enter your mobile number to complete secure sign in.',
                style: AppText.body(AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              FieldLabel('MOBILE NUMBER (+91)'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.phone_outlined,
                controller: _mobileController,
                hint: '98765 43210',
                dark: true,
                keyboardType: TextInputType.phone,
              ),
              if (_codeSentTo != null) ...[
                const SizedBox(height: 16),
                FieldLabel('6-DIGIT CODE SENT TO +91 $_codeSentTo'),
                const SizedBox(height: 8),
                EditableField(
                  icon: Icons.lock_outline,
                  controller: _codeController,
                  hint: '••••••',
                  dark: true,
                  keyboardType: TextInputType.number,
                ),
                if (_devCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Development code: $_devCode', style: AppText.bodySmall(AppColors.otpTimer)),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading || _resendIn > 0 ? null : _sendCode,
                    child: Text(_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code', style: AppText.bodySmall(AppColors.textMuted)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SolidButton(
                label: _loading ? 'Please wait…' : _codeSentTo == null ? 'Send code' : 'Verify & continue',
                background: Colors.black,
                onTap: _loading ? null : _continue,
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => showFindServerDialog(context),
                  icon: const Icon(Icons.dns_outlined, size: 16, color: AppColors.textMuted),
                  label: Text('Find server', style: AppText.bodySmall(AppColors.textMuted)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: Divider(color: AppColors.darkStroke)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR SECURELY ACCESS VIA',
                      style: AppText.bodySmall(AppColors.textFaint),
                    ),
                  ),
                  Expanded(
                      child: Divider(color: AppColors.darkStroke)),
                ],
              ),
              const SizedBox(height: 18),
              OutlineButton(
                label: 'Continue with Google',
                onTap: () {},
                background: Colors.white,
                foreground: AppColors.textDark,
                leading: const _GoogleG(),
              ),
              const SizedBox(height: 12),
              OutlineButton(
                label: 'Continue with Apple',
                onTap: () {},
                background: Colors.white,
                foreground: AppColors.textDark,
                leading: const Icon(Icons.apple, size: 20),
              ),
              const SizedBox(height: 18),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppText.caption(AppColors.textFaint),
                  children: [
                    const TextSpan(
                        text: 'By clicking continue, you agree to our '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: AppText.caption(AppColors.textMuted)
                          .copyWith(decoration: TextDecoration.underline),
                      recognizer: _termsTap,
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: AppText.caption(AppColors.textMuted)
                          .copyWith(decoration: TextDecoration.underline),
                      recognizer: _privacyTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.purpleAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleGlow.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text('Vakil', style: AppText.h1(AppColors.textWhite)),
          const SizedBox(height: 10),
          Text(
            'Instant legal protection & emergency lawyer\n'
            'dispatch. Verified Indian defense advocates on-call\n'
            '24/7.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall(AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
