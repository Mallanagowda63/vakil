import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';

/// Write to the Vakil team. The message becomes a ticket in the Admin Panel
/// (Complaints), and the team replies by email or phone.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _topics = ['Payment or wallet', 'A chat with a lawyer', 'Refund', 'App problem', 'Account', 'Other'];
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
    final text = _message.text.trim();
    if (text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tell us a little more about the problem')));
      return;
    }
    setState(() => _sending = true);
    try {
      final data = await ApiClient().post('/api/support', {'topic': _topic, 'message': text}, token: AuthService.instance.token);
      if (mounted) setState(() => _ticket = data['ticket']?.toString());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white, title: Text('Help & Support', style: AppText.h3(AppColors.textDark))),
      body: SafeArea(
        child: _ticket != null ? _sent() : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Write to the Vakil team', style: AppText.h2(AppColors.textDark)),
            const SizedBox(height: 6),
            Text('Tell us what went wrong. We reply to the email and phone number on your account.', style: AppText.bodySmall(AppColors.textGray)),
            const SizedBox(height: 20),
            Text('What is it about?', style: AppText.bodyMedium(AppColors.textDark)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _topics) ChoiceChip(label: Text(t), selected: _topic == t, onSelected: (_) => setState(() => _topic = t)),
            ]),
            const SizedBox(height: 20),
            Text('Your message', style: AppText.bodyMedium(AppColors.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              minLines: 5,
              maxLines: 10,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'For example: money was taken but not added to my wallet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SolidButton(label: _sending ? 'Sending…' : 'Send message', background: Colors.black, onTap: _sending ? null : _send),
          ]),
        ),
      ),
    );
  }

  Widget _sent() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFE6F7EE), shape: BoxShape.circle), child: const Icon(Icons.mark_email_read_outlined, color: AppColors.greenAccent, size: 34)),
          const SizedBox(height: 18),
          Text('Message sent', style: AppText.h2(AppColors.textDark)),
          const SizedBox(height: 6),
          Text('Your ticket number is $_ticket. Keep it handy if you contact us again.', textAlign: TextAlign.center, style: AppText.body(AppColors.textGray)),
          const SizedBox(height: 24),
          SolidButton(label: 'Done', background: Colors.black, onTap: () => Navigator.of(context).pop()),
        ]),
      );
}
