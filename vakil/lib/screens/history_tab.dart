import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum _ActivityType { chat, call }

class _HistoryEntry {
  const _HistoryEntry({
    required this.name,
    required this.type,
    required this.detail,
    required this.time,
    required this.day,
    required this.avatarColor,
  });

  final String name;
  final _ActivityType type;
  final String detail;
  final String time;
  final String day;
  final Color avatarColor;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

const _history = <_HistoryEntry>[
  _HistoryEntry(
    name: 'Adv Rahul Sharma',
    type: _ActivityType.chat,
    detail: 'Property case',
    time: '9:41 AM',
    day: 'Today',
    avatarColor: AppColors.blueAccent,
  ),
  _HistoryEntry(
    name: 'Jordan Diaz',
    type: _ActivityType.call,
    detail: 'Affairs talk...',
    time: '8:12 AM',
    day: 'Today',
    avatarColor: AppColors.greenAccent,
  ),
  _HistoryEntry(
    name: 'Priya Shah',
    type: _ActivityType.call,
    detail: 'Missed at 7:24 PM',
    time: 'Yesterday',
    day: 'Yesterday',
    avatarColor: AppColors.redAccent,
  ),
  _HistoryEntry(
    name: 'Ethan Cole',
    type: _ActivityType.chat,
    detail: 'Are we still on for tonight?',
    time: 'Yesterday',
    day: 'Yesterday',
    avatarColor: AppColors.amber,
  ),
  _HistoryEntry(
    name: 'Support Center',
    type: _ActivityType.call,
    detail: 'Connected for 2 min 41 sec',
    time: 'Mon',
    day: 'Mon',
    avatarColor: AppColors.purpleAccent,
  ),
];

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _searchController = TextEditingController();
  _ActivityType? _filter;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HistoryEntry> get _filtered {
    return _history.where((entry) {
      if (_filter != null && entry.type != _filter) return false;
      if (_query.isEmpty) return true;
      return entry.name.toLowerCase().contains(_query) ||
          entry.detail.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chatCount =
        _history.where((e) => e.type == _ActivityType.chat).length;
    final callCount =
        _history.where((e) => e.type == _ActivityType.call).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('History', style: AppText.h1(AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text('All chats and calls in one timeline',
                        style: AppText.bodySmall(AppColors.textGray)),
                  ],
                ),
              ),
              _RoundIconButton(
                icon: Icons.tune,
                background: Colors.white,
                foreground: AppColors.textDark,
                bordered: true,
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.add,
                background: AppColors.textDark,
                foreground: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: AppText.input(AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search chats and calls',
                hintStyle: AppText.body(AppColors.textGray),
                prefixIcon:
                    Icon(Icons.search, size: 20, color: AppColors.textGray),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Chats',
                selected: _filter == _ActivityType.chat,
                onTap: () => setState(() => _filter = _ActivityType.chat),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Calls',
                selected: _filter == _ActivityType.call,
                onTap: () => setState(() => _filter = _ActivityType.call),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navyDeep,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today',
                          style: AppText.bodySmall(AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Text('$chatCount chats · $callCount calls',
                          style: AppText.h3(Colors.white)
                              .copyWith(fontSize: 19)),
                      const SizedBox(height: 6),
                      Text(
                        'Your most recent activity is grouped together '
                        'so you can jump back in quickly.',
                        style: AppText.bodySmall(
                            Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.access_time,
                      size: 18, color: AppColors.navyDeep),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent activity', style: AppText.h3(AppColors.textDark)),
              Text('Today', style: AppText.bodySmall(AppColors.textGray)),
            ],
          ),
          const SizedBox(height: 10),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('No matching activity',
                    style: AppText.bodySmall(AppColors.textGray)),
              ),
            )
          else
            ..._filtered.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistoryRow(entry: entry),
                )),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.background,
    required this.foreground,
    this.bordered = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border:
            bordered ? Border.all(color: AppColors.lightStroke) : null,
      ),
      child: Icon(icon, size: 18, color: foreground),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.textDark : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: AppText.bodySmall(
                selected ? Colors.white : AppColors.textGray)),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final isChat = entry.type == _ActivityType.chat;
    final typeIcon = isChat ? Icons.chat_bubble : Icons.call;
    final typeColor = isChat ? AppColors.blueAccent : AppColors.greenAccent;
    final typeLabel = isChat ? 'Chat' : 'Call';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightStroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: entry.avatarColor.withValues(alpha: 0.15),
            child: Text(entry.initials,
                style: AppText.bodyMedium(entry.avatarColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: AppText.bodyMedium(AppColors.textDark)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(typeIcon, size: 13, color: typeColor),
                    const SizedBox(width: 4),
                    Text(typeLabel, style: AppText.bodySmall(typeColor)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(entry.detail,
                          style: AppText.bodySmall(AppColors.textGray),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(entry.time, style: AppText.caption(AppColors.textGray)),
        ],
      ),
    );
  }
}
