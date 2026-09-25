import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';
import 'active_consultation_chat_screen.dart';
import 'incoming_request_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final Map<String, int> _secondsLeft = {};
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final controller = context.read<DashboardController>();
    final expired = <String>[];
    for (final r in controller.requests) {
      final next = r.expiresAt != null ? r.secondsLeft : _secondsLeft.putIfAbsent(r.id, () => r.expiresInSeconds) - 1;
      _secondsLeft[r.id] = next;
      if (next <= 0) expired.add(r.id);
    }
    if (expired.isNotEmpty) {
      for (final id in expired) {
        final r = controller.requests.firstWhere((x) => x.id == id);
        controller.removeRequest(id);
        _secondsLeft.remove(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request from ${r.clientName} expired')),
          );
        }
      }
    }
    setState(() {});
  }

  String _format(int seconds) {
    final s = seconds.clamp(0, 5999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final requests = controller.requests;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Requests', style: TextStyle(fontWeight: FontWeight.w700)),
            if (requests.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${requests.length} New',
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Incoming consultations requiring your review.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? const Center(
                    child: Text('No pending requests right now', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final r = requests[i];
                      final left = _secondsLeft[r.id] ?? r.expiresInSeconds;
                      return _RequestCard(request: r, secondsLeft: left, formatTime: _format);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ConsultationRequest request;
  final int secondsLeft;
  final String Function(int) formatTime;

  const _RequestCard({required this.request, required this.secondsLeft, required this.formatTime});

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingRequestScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DashboardController>();
    final urgent = secondsLeft <= 60;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClientAvatar(name: request.clientName, photoUrl: request.photoUrl, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        request.category.toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Expires in', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text(
                      formatTime(secondsLeft),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: urgent ? AppColors.danger : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.problemSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (request.isTrial)
              const Align(alignment: Alignment.centerLeft, child: TrialBadge())
            else if (request.pricePerMinute > 0)
              Text('${request.type == ConsultationType.voice ? 'Voice call' : 'Chat'} · ₹${request.pricePerMinute}/min${request.maxMinutes > 0 ? ' · ${request.maxMinutes} min' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 13, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Personal documents stay hidden until acceptance',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await controller.rejectRequest(request.id);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Declined ${request.clientName}\'s request')));
                      } catch (error) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      bool accepted;
                      try { accepted = await controller.acceptRequest(request.id); } catch (error) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                        return;
                      }
                      if (!context.mounted) return;
                      if (!accepted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This request is no longer available')));
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ActiveConsultationChatScreen(requestId: request.id, title: request.clientName)),
                      );
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
