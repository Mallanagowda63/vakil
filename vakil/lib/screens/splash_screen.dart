import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'create_profile_screen.dart';
import 'home_shell.dart';
import 'legal_help_start_screen.dart';
import 'login_otp_screen.dart';

/// The single app entry point. Resolves the persisted session (backed by
/// the Vakil API + MongoDB) and routes straight to wherever the user left
/// off: sign in, finish their profile, use their free chat, or — once
/// that's spent — the full home dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 1400));
    await Future.wait([AuthService.instance.init(), minDelay]);
    _goNext();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final auth = AuthService.instance;
    final Widget next;
    if (!auth.isLoggedIn) {
      next = const LoginOtpScreen();
    } else if (!auth.profileComplete) {
      next = CreateProfileScreen(phoneNumber: auth.phone);
    } else if (!auth.trialUsed) {
      next = const LegalHelpStartScreen();
    } else {
      next = const HomeShell();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBlue,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext,
        child: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 56,
              color: AppColors.splashBlue,
            ),
          ),
        ),
      ),
    );
  }
}
