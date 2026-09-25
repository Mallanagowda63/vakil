import 'package:flutter/material.dart';
import '../state/home_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'chat_list_screen.dart';
import 'home_tab.dart';
import 'lawyers_screen.dart';
import 'profile_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  /// 0 Home, 1 Chats, 2 Lawyers, 3 Profile.
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // The selected tab lives in HomeNav so the home screen can switch to the
  // Lawyers tab with a speciality filter.
  int get _index => HomeNav.tab.value;

  static const _tabs = [
    HomeTab(),
    ChatListScreen(),
    LawyersScreen(followHomeFilter: true),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    HomeNav.tab.value = widget.initialIndex;
    if (widget.initialIndex != HomeNav.lawyers) HomeNav.speciality.value = null;
    HomeNav.tab.addListener(_changed);
  }

  @override
  void dispose() {
    HomeNav.tab.removeListener(_changed);
    super.dispose();
  }

  void _changed() { if (mounted) setState(() {}); }

  void _select(int index) => HomeNav.tab.value = index;

  @override
  Widget build(BuildContext context) {
    // Back on another tab returns to Home; on Home it leaves as usual.
    return PopScope(
      canPop: _index == HomeNav.home,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _select(HomeNav.home); },
      child: Scaffold(
      backgroundColor: AppColors.lightBg,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.lightStroke)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  selected: _index == 0,
                  onTap: () => _select(0),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Chats',
                  selected: _index == 1,
                  onTap: () => _select(1),
                ),
                _NavItem(
                  icon: Icons.gavel_outlined,
                  activeIcon: Icons.gavel,
                  label: 'Lawyers',
                  selected: _index == 2,
                  // The Lawyers tab from the bar shows every lawyer.
                  onTap: () => HomeNav.openLawyers(),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  selected: _index == 3,
                  onTap: () => _select(3),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textDark : AppColors.textGraySoft;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label, style: AppText.caption(color)),
          ],
        ),
      ),
    );
  }
}
