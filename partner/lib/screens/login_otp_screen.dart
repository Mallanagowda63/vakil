import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'activation_pending_screen.dart';
import 'personal_details_screen.dart';
import '../services/partner_auth_service.dart';
import '../widgets/server_address_dialog.dart';


class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key, this.initialEmail, this.message});
  /// Prefilled email, e.g. the one just used in the registration form.
  final String? initialEmail;
  /// Shown above the form, e.g. why signing in is needed now.
  final String? message;

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final _emailCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;
  bool _sending = false;
  bool _verifying = false;
  String? _otpError;
  /// Development only: shown on screen until an SMS provider is connected.
  String? _devCode;
  Timer? _resendTimer;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  /// The email address typed by the lawyer; the sign-in code is sent there.
  String get _email => _emailCtrl.text.trim().toLowerCase();

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    setState(() => _sending = true);
    Map<String, dynamic> res;
    try {
      res = await PartnerAuthService.instance.requestOtp(_email);
    } on PartnerNetworkException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _otpSent = true;
      _otpError = null;
    });
    _startResendTimer();
    // Development only: the server returns the code until email is connected.
    setState(() => _devCode = kDebugMode ? res['devCode']?.toString() : null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code sent to $_email')));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) FocusScope.of(context).requestFocus(_otpFocus.first);
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _otpError = 'Enter the complete 6-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _otpError = null;
    });
    try {
      await PartnerAuthService.instance.verifyOtp(_email, code);
    } on PartnerNetworkException catch (error) {
      if (!mounted) return;
      setState(() { _verifying = false; _otpError = error.message; });
      for (final c in _otpCtrls) {
        c.clear();
      }
      FocusScope.of(context).requestFocus(_otpFocus.first);
      return;
    }
    if (!mounted) return;
    setState(() => _verifying = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PartnerHome()),
      (route) => false,
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_otpFocus[index + 1]);
    }
    if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_otpFocus[index - 1]);
    }
    if (_otpCtrls.every((c) => c.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  void _unimplementedSocial(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in requires backend setup — coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Vakil Partner',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Sign In',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the 6-digit code sent to $_email. Check your inbox (and the spam folder).'
                    : "Enter your email address and we'll email you a 6-digit code to complete sign-in.",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.45),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(widget.message!, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ],
              const SizedBox(height: 28),
              if (!_otpSent) ...[
                const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'name@example.com',
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(label: 'Send code', loading: _sending, onPressed: _sending ? null : _sendOtp),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showFindServerDialog(context),
                    icon: const Icon(Icons.dns_outlined, size: 16),
                    label: const Text('Find server'),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 44,
                      height: 52,
                      child: TextField(
                        controller: _otpCtrls[i],
                        focusNode: _otpFocus[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(counterText: ''),
                        onChanged: (v) => _onOtpChanged(i, v),
                      ),
                    );
                  }),
                ),
                if (_otpError != null) ...[
                  const SizedBox(height: 10),
                  Text(_otpError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ],
                if (_devCode != null) ...[
                  const SizedBox(height: 10),
                  Text('Partner app code (development): $_devCode', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend code in 0:${_resendSeconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                        )
                      : TextButton(
                          onPressed: _sendOtp,
                          child: const Text('Resend code'),
                        ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Verify & Continue', loading: _verifying, onPressed: _verifying ? null : _verifyOtp),
              ],
              const SizedBox(height: 28),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Continue with Google',
                outlined: true,
                icon: Icons.g_mobiledata,
                onPressed: () => _unimplementedSocial('Google'),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Continue with Apple',
                outlined: true,
                icon: Icons.apple,
                onPressed: () => _unimplementedSocial('Apple'),
              ),
              const SizedBox(height: 28),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      text: 'New to Vakil Partner? ',
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Create a partner account',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
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
