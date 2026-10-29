import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/dashboard_data.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import 'consultation_summary_screen.dart';
import '../widgets/app_loader.dart';

/// Every finished consultation, newest first (GET /api/chats). Tap one for its
/// details, earnings and feedback.
class ConsultationLogsScreen extends StatefulWidget {
  const ConsultationLogsScreen({super.key});

  @override
  State<ConsultationLogsScreen> createState() => _ConsultationLogsScreenState();
}

class _ConsultationLogsScreenState extends State<ConsultationLogsScreen> {
  List<ChatSummary>? _logs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    setState(() => _error = null);
    try {
      final chats = await PartnerConsultationService().chats(token);
      if (mounted) setState(() => _logs = chats.where((c) => c.status == 'COMPLETED').toList());
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  static String _when(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final time = '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
    if (day == today) return 'Today, $time';
    if (today.difference(day).inDays == 1) return 'Yesterday, $time';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final logs = _logs;
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation Logs')),
      body: logs == null
          ? (_error == null ? const PageLoader() : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: _load, child: const Text('Try again'))])))
          : logs.isEmpty
              ? const Center(child: Text('Finished consultations will show here.', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      final free = log.isTrial && log.totalAmount == 0;
                      return Material(
                        color: AppColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsultationSummaryScreen(requestId: log.requestId, clientName: log.other.name))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(log.other.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                const SizedBox(height: 3),
                                Text([if (log.category.isNotEmpty) log.category, _when(log.lastActivityAt)].join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(free ? 'Free trial' : rupees(log.totalAmount), style: TextStyle(fontWeight: FontWeight.w700, color: free ? AppColors.textSecondary : AppColors.textPrimary)),
                                if (log.billedMinutes > 0) Text('${log.billedMinutes} min', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                              ]),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
