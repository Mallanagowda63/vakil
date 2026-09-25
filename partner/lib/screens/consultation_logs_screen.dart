import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';

class ConsultationLogsScreen extends StatelessWidget {
  const ConsultationLogsScreen({super.key});

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final isToday = t.year == now.year && t.month == now.day && t.day == now.day;
    final isYesterday = now.difference(t).inDays == 1;
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:${t.minute.toString().padLeft(2, '0')} $ampm';
    if (isToday) return 'Today, $time';
    if (isYesterday) return 'Yesterday, $time';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<DashboardController>().callLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultation Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              'Secure client calls conducted inside the Vakil platform',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No consultations yet', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final log = logs[i];
                final min = log.duration.inMinutes;
                final sec = log.duration.inSeconds % 60;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatTime(log.time)} · ${log.referenceId}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    log.category,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Duration: ${min}m ${sec}s',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.mic_none, size: 12, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Recording', style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${log.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
