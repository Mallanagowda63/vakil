import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/partner_auth_service.dart';
import 'dashboard_screen.dart';
import 'login_otp_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    Future.wait([PartnerAuthService.instance.restore(), Future.delayed(const Duration(milliseconds: 1200))]).then((results) {
      if (!mounted) return;
      final signedIn = results.first as bool;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => signedIn ? const DashboardScreen() : const LoginOtpScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 46,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vakil Partner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
