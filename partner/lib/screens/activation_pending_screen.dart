import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../services/registration_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'dashboard_screen.dart';
import 'login_otp_screen.dart';
import 'personal_details_screen.dart';

/// The lawyer's verification state from the server: approved, under_review,
/// rejected (with a reason), not_submitted or suspended.
Future<({String status, String reason})> fetchVerification(String token) async {
  final profile = await PartnerConsultationService().profile(token);
  return (status: profile['verificationStatus']?.toString() ?? 'not_submitted', reason: profile['rejectionReason']?.toString() ?? '');
}

/// Where a signed-in lawyer starts: the dashboard once the Vakil team has
/// verified them, otherwise the waiting screen (which opens the dashboard by
/// itself the moment the admin taps Verify).
class PartnerHome extends StatefulWidget {
  const PartnerHome({super.key});
  @override
  State<PartnerHome> createState() => _PartnerHomeState();
}

class _PartnerHomeState extends State<PartnerHome> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final token = PartnerAuthService.instance.token;
    var approved = true;
    if (token != null) {
      // A registration filled in before sign-in goes to the Admin Panel now.
      await RegistrationSync.flush(token);
      try {
        approved = (await fetchVerification(token)).status == 'approved';
      } catch (_) {
        // Offline: open the dashboard as before; the server still blocks an unverified lawyer.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => approved ? const DashboardScreen() : const ActivationPendingScreen()));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ActivationPendingScreen extends StatefulWidget {
  const ActivationPendingScreen({super.key});

  @override
  State<ActivationPendingScreen> createState() => _ActivationPendingScreenState();
}

class _ActivationPendingScreenState extends State<ActivationPendingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _poll;
  String _status = 'under_review';
  String _reason = '';

  bool get _signedIn => PartnerAuthService.instance.token != null;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    // Signed in: check every few seconds and open the app once verified.
    if (_signedIn) {
      _check();
      _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      await RegistrationSync.flush(token);
      final v = await fetchVerification(token);
      if (!mounted) return;
      if (v.status == 'approved') {
        _poll?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account is verified. Welcome to Vakil Partner!')));
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (route) => false);
        return;
      }
      setState(() { _status = v.status; _reason = v.reason; });
    } catch (_) {}
  }

  void _openRegistration() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()));

  Future<void> _signOut() async {
    if (_signedIn) await PartnerAuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginOtpScreen()), (route) => false);
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
                  child: Icon(_status == 'rejected' ? Icons.error_outline : Icons.access_time_filled, size: 44, color: _status == 'rejected' ? AppColors.danger : AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                switch (_status) { 'rejected' => 'Registration needs changes', 'not_submitted' => 'Complete your registration', 'suspended' => 'Account suspended', _ => 'Activating your account' },
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                switch (_status) {
                  'rejected' => _reason.isNotEmpty ? 'The Vakil team could not verify your registration:\n\n"$_reason"\n\nPlease fix it and send your registration again.' : 'The Vakil team could not verify your registration. Please check your details and documents and send it again.',
                  'not_submitted' => 'We have not received your registration yet. Fill in your details and upload your documents so the Vakil team can verify you.',
                  'suspended' => 'Your account has been suspended. Please contact support.',
                  _ => 'Our team is reviewing your registration and documents. This page opens your account by itself as soon as you are verified, and we will also send you a notification.',
                },
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 36),
              if (_status == 'rejected' || _status == 'not_submitted')
                PrimaryButton(label: _status == 'rejected' ? 'Fix and send again' : 'Complete registration', onPressed: _openRegistration)
              else
                const PrimaryButton(label: 'Wait for confirmation', onPressed: null),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _contactSupport,
                child: const Text('Contact Support'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _signOut,
                child: Text(_signedIn ? 'Sign out' : 'Back to Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
