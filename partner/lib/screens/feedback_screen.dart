import 'package:flutter/material.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import 'active_consultation_chat_screen.dart';

/// Feedback after chats and calls: clients' ratings of me (my public rating)
/// and the feedback I gave clients.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      final data = await PartnerConsultationService().feedback(token);
      if (mounted) setState(() { _data = data; _error = null; });
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  List<Map<String, dynamic>> _list(String key) => (_data?[key] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Widget build(BuildContext context) {
    final received = _list('received');
    final given = _list('given');
    final stats = Map<String, dynamic>.from(_data?['stats'] as Map? ?? const {});
    final average = (stats['receivedAverage'] as num?)?.toDouble();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feedback & Ratings'),
          bottom: TabBar(tabs: [Tab(text: 'From clients (${received.length})'), Tab(text: 'I gave (${given.length})')]),
        ),
        body: _error != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: _load, child: const Text('Try again'))]))
            : _data == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _FeedbackList(
                      items: received,
                      header: average == null ? null : 'Your rating: ★ ${average.toStringAsFixed(1)} from ${received.length} ${received.length == 1 ? 'client' : 'clients'}',
                      empty: 'No client ratings yet.\nClients can rate each chat or call when it ends.',
                      onRefresh: _load,
                    ),
                    _FeedbackList(items: given, empty: "You haven't rated a client yet.\nRate them on the summary screen after a consultation.", onRefresh: _load),
                  ]),
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({required this.items, required this.empty, required this.onRefresh, this.header});
  final List<Map<String, dynamic>> items;
  final String empty;
  final String? header;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: items.isEmpty
          ? ListView(children: [const SizedBox(height: 120), Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary))])
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (header != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(header!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: FeedbackCard(item: item)),
            ]),
    );
  }
}

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final other = Map<String, dynamic>.from(item['other'] as Map? ?? const {});
    final rating = (item['rating'] as num?)?.toInt() ?? 0;
    final comment = item['comment']?.toString() ?? '';
    final isCall = item['consultationType'] == 'call';
    final date = DateTime.tryParse(item['createdAt']?.toString() ?? '')?.toLocal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClientAvatar(name: other['name']?.toString() ?? 'Client', photoUrl: other['photoUrl'] as String?, radius: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(other['name']?.toString() ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            if (date != null) Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            for (var s = 1; s <= 5; s++) Icon(s <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: const Color(0xFFF5A623)),
            const SizedBox(width: 6),
            Icon(isCall ? Icons.call_outlined : Icons.chat_bubble_outline, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Flexible(child: Text([isCall ? 'Voice call' : 'Chat', if (item['category'] != null) item['category'].toString()].join(' · '), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          ]),
          if (comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(comment, style: const TextStyle(fontSize: 13))),
        ])),
      ]),
    );
  }
}
