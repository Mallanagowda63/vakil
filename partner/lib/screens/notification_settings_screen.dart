import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../services/partner_settings.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _settings = PartnerSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Availability and alert sounds',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            _switchTile(
              context.watch<DashboardController>().onlineStatus ? 'Online' : 'Offline',
              'Online: clients can send you new chat requests',
              context.watch<DashboardController>().onlineStatus,
              (v) => context.read<DashboardController>().setOnlineStatus(v),
            ),
            _switchTile(
              'Sound',
              'Ringtone for new requests and a ding for new messages',
              _settings.soundOn,
              _settings.setSound,
            ),
            _switchTile(
              'Vibration',
              'Vibrate with request and message alerts',
              _settings.vibrationOn,
              _settings.setVibration,
            ),
            const SizedBox(height: 8),
            const Text(
              'When the app is closed, alerts use your phone\'s notification settings for "Chat requests" and "Messages".',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.success),
        ],
      ),
    );
  }
}
