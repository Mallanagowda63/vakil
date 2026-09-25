import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'connected_call_screen.dart';
import 'dashboard_screen.dart';

class CallReceiptScreen extends StatefulWidget {
  final ConsultationRequest request;
  final int callSeconds;
  final int chatSeconds;
  final CallEndReason reason;

  const CallReceiptScreen({
    super.key,
    required this.request,
    required this.callSeconds,
    required this.chatSeconds,
    required this.reason,
  });

  @override
  State<CallReceiptScreen> createState() => _CallReceiptScreenState();
}

class _CallReceiptScreenState extends State<CallReceiptScreen> {
  late final TextEditingController _notesCtrl = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _statusHeadline {
    switch (widget.reason) {
      case CallEndReason.networkFailure:
        return 'Call Ended — Connection Lost';
      case CallEndReason.lowBalance:
        return 'Call Ended — Low Balance';
      case CallEndReason.manual:
        return 'Call Ended Securely';
    }
  }

  void _saveAndReturn() {
    if (_saved) return;
    _saved = true;
    final r = widget.request;
    final minutes = (widget.callSeconds / 60).ceil().clamp(1, r.maxMinutes);
    final total = minutes * r.pricePerMinute;
    context.read<DashboardController>().addCallLog(
          CallLogEntry(
            clientName: r.clientName,
            referenceId: 'VP-CALL-${(r.id.hashCode.abs() % 9000) + 1000}',
            time: DateTime.now(),
            amount: total.toDouble(),
            category: r.category,
            duration: Duration(seconds: widget.callSeconds),
          ),
        );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final minutes = (widget.callSeconds / 60).ceil().clamp(1, r.maxMinutes);
    final totalEarned = minutes * r.pricePerMinute;
    final chatMinutes = (widget.chatSeconds / 60).ceil();
    final callMin = widget.callSeconds ~/ 60;
    final callSec = widget.callSeconds % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Consultation Receipt')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(color: Color(0xFFE6F7EE), shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: AppColors.success, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(_statusHeadline, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Reference ID: VP-CALL-${(r.id.hashCode.abs() % 9000) + 1000}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    _row('Consultant', '${r.clientName} (Client)'),
                    _row('Case Category', r.category),
                    _row('Recording Status', 'Saved & Encrypted', valueColor: AppColors.success),
                    const Divider(height: 28),
                    _row('Call Duration', '$callMin min $callSec sec'),
                    _row('Billing Rate', '₹${r.pricePerMinute}/min'),
                    if (widget.chatSeconds > 0) ...[
                      _row('Chat Duration', '$chatMinutes min'),
                      _row('Chat Payment', 'Connected +₹200.00', valueColor: AppColors.success),
                    ],
                    const Divider(height: 28),
                    _row('Total Earned', '₹${totalEarned.toStringAsFixed(2)}', bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5DCC0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB5751B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Low balance warning\nIf the balance is low, the call will end automatically. '
                        'The user can reconnect within 4 minutes.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB5751B), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Notes (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Add any notes about this consultation...'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Save Notes & Return to Dashboard', onPressed: _saveAndReturn),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
