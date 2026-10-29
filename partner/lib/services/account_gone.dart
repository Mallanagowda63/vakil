import 'package:flutter/material.dart';
import '../screens/login_otp_screen.dart';
import '../screens/personal_details_screen.dart';
import '../theme/app_theme.dart';
import 'app_keys.dart';
import 'partner_auth_service.dart';

/// The Vakil team deleted this lawyer's account (Admin Panel → Delete). Signs
/// out, opens the sign-in screen and explains, with a way to register again.
/// Triggered by the live 'account_deleted' notice, a refused live connection
/// or any server reply with code 'account_deleted'; runs once.
class AccountGone {
  AccountGone._();
  static bool _showing = false;

  static Future<void> show() async {
    if (_showing) return;
    _showing = true;
    await PartnerAuthService.instance.logout();
    final navigator = navigatorKey.currentState;
    if (navigator == null) { _showing = false; return; }
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginOtpScreen()), (route) => false);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) { _showing = false; return; }
    final register = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: Color(0xFFFDECEC), shape: BoxShape.circle),
          child: const Icon(Icons.person_off_outlined, color: AppColors.danger, size: 28),
        ),
        title: const Text('Your account was removed', textAlign: TextAlign.center),
        content: const Text(
          'The Vakil team has deleted your Legally Talk Partner account, so you have been signed out.\n\n'
          'To work with Vakil again, please create a new account and complete the registration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Close')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create new account')),
        ],
      ),
    );
    _showing = false;
    if (register == true) navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()));
  }
}
