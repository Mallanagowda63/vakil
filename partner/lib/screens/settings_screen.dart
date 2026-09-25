import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../models/profile_data.dart';
import '../models/theme_controller.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import 'customer_support_screen.dart';
import 'feedback_screen.dart';
import 'login_otp_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Future<void> _logOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      // Go offline for new requests, drop the connection and forget the session.
      final controller = context.read<DashboardController>();
      final token = PartnerAuthService.instance.token;
      if (token != null) {
        try { await controller.consultationService.presence(token, false); } catch (_) {}
      }
      controller.disconnect();
      await PartnerAuthService.instance.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginOtpScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text(profile.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openProfile(context),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.infoBg,
                      backgroundImage: profile.avatarImage,
                      child: profile.avatarImage == null
                          ? Text(profile.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // What the lawyer gave at registration, as stored on the server.
              InkWell(
                onTap: () => _openProfile(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(child: Text('Registration details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      Text('Edit', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ]),
                    const SizedBox(height: 10),
                    for (final (label, value) in [
                      ('Name', profile.name),
                      ('Mobile', profile.phone),
                      ('Email', profile.email),
                      ('Gender', profile.gender),
                      ('Date of birth', profile.dateOfBirth),
                      ('Bar Council no.', profile.barCouncilRegNo),
                      ('Practice areas', profile.specialization),
                      ('Court', profile.court),
                      ('City', profile.location),
                      ('Languages', profile.languages),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _tile(
                icon: themeController.isDark ? Icons.dark_mode_outlined : Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Switch between light and dark appearance',
                trailing: Switch(
                  value: themeController.isDark,
                  onChanged: (v) => themeController.setDark(v),
                  activeThumbColor: AppColors.success,
                ),
              ),
              _tile(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle: 'Manage alerts and reminders',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                ),
              ),
              _tile(
                icon: Icons.person_outline,
                title: 'Account Options',
                subtitle: 'Update profile and preferences',
                onTap: () => _openProfile(context),
              ),
              _tile(
                icon: Icons.star_outline_rounded,
                title: 'Feedback & Ratings',
                subtitle: 'What clients said about you, and your feedback on them',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              _tile(
                icon: Icons.support_agent_outlined,
                title: 'Customer Support',
                subtitle: 'Get help with your account and services',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerSupportScreen()),
                ),
              ),
              _tile(
                icon: Icons.logout,
                title: 'Log Out',
                subtitle: 'Sign out of your Vakil Partner account',
                iconColor: AppColors.danger,
                titleColor: AppColors.danger,
                onTap: () => _logOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: titleColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textSecondary) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
