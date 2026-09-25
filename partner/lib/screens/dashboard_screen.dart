import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../models/profile_data.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_banner.dart';
import 'chat_list_screen.dart';
import 'consultation_logs_screen.dart';
import 'practice_areas_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import '../services/partner_auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final token = PartnerAuthService.instance.token;
    final controller = context.read<DashboardController>();
    if (token != null) Future.microtask(() => controller.connectBackend(token));
  }

  @override
  Widget build(BuildContext context) {
    final requestCount = context.watch<DashboardController>().requests.length;

    final pages = <Widget>[
      _DashboardHomeTab(onNavigate: (i) => setState(() => _tabIndex = i)),
      const RequestsScreen(),
      const ChatListScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: requestCount > 0,
              label: Text('$requestCount'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: const Icon(Icons.inbox),
            label: 'Requests',
          ),
          const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _DashboardHomeTab extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _DashboardHomeTab({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final profile = context.watch<ProfileController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary,
                backgroundImage: profile.avatarImage,
                child: profile.avatarImage == null
                    ? Text(profile.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    Text(
                      profile.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onNavigate(3),
                icon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              IconButton(
                onPressed: () => showNotificationBanner(
                  context,
                  title: 'Notification',
                  time: 'Just now',
                  message: 'You have a new message from your legal partner. '
                      'Open the app to review the update.',
                  onView: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RequestsScreen()),
                  ),
                ),
                icon: const Icon(Icons.notifications_none_outlined),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _onlineToggle(controller),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Availability', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                _availabilityRow(
                  'Chat available',
                  controller.availableForChat && controller.chatAllowed,
                  controller.chatAllowed ? controller.setAvailableForChat : null,
                  hint: controller.chatAllowed ? 'Clients can send you chat requests' : 'Turned off by Vakil admin',
                ),
                _availabilityRow(
                  'Call available',
                  controller.availableForCall && controller.callAllowed,
                  controller.callAllowed ? controller.setAvailableForCall : null,
                  hint: controller.callAllowed ? 'Clients can call you' : 'Turned off by Vakil admin',
                ),
                if (!controller.onlineStatus)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text("You're offline. Turn on Chat or Call to receive requests.", style: TextStyle(fontSize: 12.5, color: AppColors.danger)),
                  ),
                const Divider(height: 24),
                const Text('Practice Areas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _pickPracticeAreas(context, controller),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            controller.practiceAreas.isEmpty
                                ? 'Choose your practice areas...'
                                : controller.practiceAreas.join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: controller.practiceAreas.isEmpty
                                  ? const Color(0xFF9AA1AE)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Today's Overview", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statTile(Icons.forum_outlined, '${controller.stats.consultationsToday}', 'Consultations'),
              _statTile(Icons.currency_rupee, rupees(controller.stats.earningsToday), 'Earnings'),
              _statTile(Icons.schedule_outlined, '${controller.stats.minutesToday}m', 'Minutes'),
              _statTile(Icons.phone_missed_outlined, '${controller.stats.missedToday}', 'Missed'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Financials & Reputation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onNavigate(3),
            child: _card(
              child: Column(
                children: [
                  _financialRow('Pending Payout', rupees(controller.financials.pendingPayout)),
                  const Divider(height: 24),
                  _financialRow('Completed Payouts', rupees(controller.financials.completedPayouts)),
                  const Divider(height: 24),
                  _financialRow(
                    'Rating & Reputation',
                    '★ ${LawyerProfile.rating} (${LawyerProfile.ratingCount})',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => onNavigate(3),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  label: const Text('Open Vakil Wallet'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConsultationLogsScreen()),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('View Consultation Logs'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPracticeAreas(BuildContext context, DashboardController controller) async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => PracticeAreasScreen(initiallySelected: controller.practiceAreas),
      ),
    );
    if (selected != null) controller.setPracticeAreas(selected);
  }

  /// One switch for chat and calls together; the separate switches below stay.
  Widget _onlineToggle(DashboardController controller) {
    final online = controller.onlineStatus;
    final color = online ? AppColors.success : AppColors.textSecondary;
    return Material(
      color: online ? AppColors.success.withValues(alpha: .10) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.setOnlineStatus(!online),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: online ? AppColors.success : AppColors.border)),
          child: Row(children: [
            Icon(online ? Icons.wifi_tethering : Icons.wifi_tethering_off, color: color),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(online ? 'You are Online' : 'You are Offline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: online ? AppColors.success : AppColors.textPrimary)),
              Text(online ? 'Clients can chat with you and call you' : 'Turn on to receive chats and calls', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Switch(value: online, onChanged: controller.setOnlineStatus, activeThumbColor: AppColors.success),
          ]),
        ),
      ),
    );
  }

  Widget _availabilityRow(String label, bool value, ValueChanged<bool>? onChanged, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              if (hint != null) Text(hint, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.success),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _financialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

