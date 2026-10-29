import 'package:flutter/material.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// Write to the Vakil team. The message becomes a ticket in the Admin Panel
/// (Complaints), and the team replies by email or phone.
class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  static const _topics = ['Payouts', 'Verification', 'Chats & requests', 'App problem', 'Account', 'Other'];
  final _message = TextEditingController();
  String _topic = _topics.first;
  bool _sending = false;
  String? _ticket;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final token = PartnerAuthService.instance.token;
    final text = _message.text.trim();
    if (token == null) return;
    if (text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tell us a little more about the problem')));
      return;
    }
    setState(() => _sending = true);
    try {
      final ticket = await PartnerConsultationService().contactSupport(token, topic: _topic, message: text);
      if (mounted) setState(() => _ticket = ticket);
    } on PartnerNetworkException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SafeArea(
        child: _ticket != null ? _sent() : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Write to the Vakil team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Tell us what went wrong. We reply to the email and phone number on your account.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            const Text('What is it about?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _topics) ChoiceChip(label: Text(t), selected: _topic == t, onSelected: (_) => setState(() => _topic = t)),
            ]),
            const SizedBox(height: 20),
            const Text('Your message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              minLines: 5,
              maxLines: 10,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'For example: my payout from last week has not arrived', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Send message', loading: _sending, onPressed: _sending ? null : _send),
          ]),
        ),
      ),
    );
  }

  Widget _sent() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFE6F7EE), shape: BoxShape.circle), child: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 34)),
          const SizedBox(height: 18),
          const Text('Message sent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Your ticket number is $_ticket. Keep it handy if you contact us again.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        ]),
      );
}
