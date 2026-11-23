import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../models/profile_data.dart';
import '../models/wallet_data.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import 'tabs/consults_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/partner_nav.dart';
import 'tabs/profile_tab.dart';

/// The signed-in partner app: Home, Consults, Earnings and Profile, with the
/// floating dark tab bar from the design.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    PartnerNav.tab.value = PartnerNav.home;
    final token = PartnerAuthService.instance.token;
    final controller = context.read<DashboardController>();
    if (token != null) Future.microtask(() => controller.connectBackend(token));
    Future.microtask(() {
      if (!mounted) return;
      context.read<ProfileController>().load();
      context.read<WalletController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final waiting = context.watch<DashboardController>().requests.length;
    return ValueListenableBuilder<int>(
      valueListenable: PartnerNav.tab,
      builder: (context, tab, _) => PopScope(
        // Back on another tab goes Home first.
        canPop: tab == PartnerNav.home,
        onPopInvokedWithResult: (didPop, _) { if (!didPop) PartnerNav.tab.value = PartnerNav.home; },
        child: Scaffold(
          backgroundColor: c.bg,
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: tab, children: const [HomeTab(), ConsultsTab(), EarningsTab(), ProfileTab()]),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: c.nav, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12))]),
              child: Row(children: [
                _NavItem(icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home', index: PartnerNav.home, current: tab),
                _NavItem(icon: Icons.chat_bubble_outline, active: Icons.chat_bubble, label: 'Consults', index: PartnerNav.consults, current: tab, badge: waiting),
                _NavItem(icon: Icons.account_balance_wallet_outlined, active: Icons.account_balance_wallet, label: 'Earnings', index: PartnerNav.earnings, current: tab),
                _NavItem(icon: Icons.person_outline, active: Icons.person, label: 'Profile', index: PartnerNav.profile, current: tab),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.active, required this.label, required this.index, required this.current, this.badge = 0});
  final IconData icon, active;
  final String label;
  final int index, current, badge;

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final on = index == current;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index == PartnerNav.consults && current != index) PartnerNav.consultsSegment.value = 'consults';
          PartnerNav.tab.value = index;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 7),
          decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(17)),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(on ? active : icon, size: 21, color: on ? c.navOn : c.navInk),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: on ? c.navOn : c.navInk)),
            ]),
            if (badge > 0) Positioned(
              top: -3, right: 18,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(99)),
                child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D1404))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
