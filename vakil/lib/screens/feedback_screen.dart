import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/chat_format.dart';
import 'lawyers_screen.dart';

/// Feedback after chats and calls: what lawyers said about me, and the
/// ratings I gave them.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  ({List<FeedbackEntry> given, List<FeedbackEntry> received})? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ProfileService.instance.feedback();
      if (mounted) setState(() { _data = data; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(
          title: Text('Feedback & Ratings', style: AppText.h3(AppColors.textDark)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: TabBar(tabs: [
            Tab(text: 'From lawyers${data == null ? '' : ' (${data.received.length})'}'),
            Tab(text: 'My ratings${data == null ? '' : ' (${data.given.length})'}'),
          ]),
        ),
        body: _error != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: AppText.body(AppColors.textGray)), TextButton(onPressed: _load, child: const Text('Try again'))]))
            : data == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _FeedbackList(items: data.received, empty: 'No feedback from lawyers yet.\nIt appears here after a lawyer rates a chat or call with you.', onRefresh: _load),
                    _FeedbackList(items: data.given, empty: "You haven't rated a lawyer yet.\nYou can rate each chat or call when it ends.", onRefresh: _load),
                  ]),
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({required this.items, required this.empty, required this.onRefresh});
  final List<FeedbackEntry> items;
  final String empty;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: items.isEmpty
          ? ListView(children: [const SizedBox(height: 120), Text(empty, textAlign: TextAlign.center, style: AppText.body(AppColors.textGray))])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => FeedbackCard(entry: items[i]),
            ),
    );
  }
}

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({super.key, required this.entry});
  final FeedbackEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightStroke)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LawyerAvatar(name: entry.otherName, photoUrl: entry.otherPhotoUrl, radius: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(entry.otherName, style: AppText.bodyMedium(AppColors.textDark), overflow: TextOverflow.ellipsis)),
            if (entry.createdAt != null) Text(dayLabel(entry.createdAt!), style: AppText.caption(AppColors.textGray)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            for (var s = 1; s <= 5; s++) Icon(s <= entry.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: AppColors.starGold),
            const SizedBox(width: 6),
            Icon(entry.isCall ? Icons.call_outlined : Icons.chat_bubble_outline, size: 13, color: AppColors.textGray),
            const SizedBox(width: 3),
            Flexible(child: Text([entry.isCall ? 'Voice call' : 'Chat', if (entry.category != null) entry.category!].join(' · '), style: AppText.caption(AppColors.textGray), overflow: TextOverflow.ellipsis)),
          ]),
          if (entry.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(entry.comment, style: AppText.bodySmall(AppColors.textDark))),
        ])),
      ]),
    );
  }
}
