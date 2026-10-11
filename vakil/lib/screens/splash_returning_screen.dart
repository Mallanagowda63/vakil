import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
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
      backgroundColor: AppLogo.splashBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: const Center(child: AppLogo(width: 260)),
      ),
    );
  }
}
