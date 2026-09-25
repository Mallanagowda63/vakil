import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'home_shell.dart';

/// Shown on subsequent app opens once the user has completed their
/// first free session and is a returning member — leads into the
/// full lawyer-discovery home dashboard rather than the onboarding flow.
class SplashReturningScreen extends StatefulWidget {
  const SplashReturningScreen({super.key});

  @override
  State<SplashReturningScreen> createState() => _SplashReturningScreenState();
}

class _SplashReturningScreenState extends State<SplashReturningScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    });
  }

  void _skip() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBlue,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Vakil', style: AppText.h1(Colors.white).copyWith(fontSize: 30)),
              const SizedBox(height: 4),
              Text(
                'Let\'s Talk Our Rights',
                style: AppText.bodySmall(Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
