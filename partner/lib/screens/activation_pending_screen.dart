import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'login_otp_screen.dart';

class ActivationPendingScreen extends StatefulWidget {
  const ActivationPendingScreen({super.key});

  @override
  State<ActivationPendingScreen> createState() => _ActivationPendingScreenState();
}

class _ActivationPendingScreenState extends State<ActivationPendingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _contactSupport() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email support'),
              subtitle: const Text('support@vakilpartner.com'),
              onTap: () => Navigator.pop(sheetContext, 'mailto:support@vakilpartner.com'),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Call support'),
              subtitle: const Text('+91 98765 43210'),
              onTap: () => Navigator.pop(sheetContext, 'tel:+919876543210'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final uri = Uri.parse(result);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.infoBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled, size: 44, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Activating your account',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Our team is currently reviewing your application. This process '
                "usually takes 24-48 hours. We'll send you an email as soon as "
                'your account is ready to use.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 36),
              const PrimaryButton(label: 'Wait for confirmation', onPressed: null),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _contactSupport,
                child: const Text('Contact Support'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginOtpScreen()),
                  (route) => false,
                ),
                child: const Text('Back to Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
