import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

enum _Sender { agent, user }

class _SupportMessage {
  final _Sender sender;
  final String text;
  const _SupportMessage(this.sender, this.text);
}

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  final _messages = <_SupportMessage>[
    const _SupportMessage(_Sender.agent, "Hi there! I'm Aisha from Vakil Partner support. How can I help you today?"),
    const _SupportMessage(_Sender.user, "I'm trying to update my case documents, but the upload keeps failing."),
    const _SupportMessage(
      _Sender.agent,
      "I can help with that. If you'd like faster assistance, tap the call button below and I'll connect you with a support agent right away.",
    ),
    const _SupportMessage(_Sender.user, 'A quick call would be great, thanks.'),
  ];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _agentTyping = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_SupportMessage(_Sender.user, text));
      _inputCtrl.clear();
      _agentTyping = true;
    });
    _scrollToBottom();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _agentTyping = false;
        _messages.add(const _SupportMessage(
          _Sender.agent,
          "Got it — thanks for the details. I'll take a look and follow up shortly.",
        ));
      });
      _scrollToBottom();
    });
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:+919876543210');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start a call on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Vakil Partner help desk', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7EE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: AppColors.success),
                    SizedBox(width: 5),
                    Text('Live now', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: AppColors.card,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.infoBg,
                  child: Text('AS', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aisha · Support Specialist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text('Usually replies in under 2 minutes', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Color(0xFFE8B84B)),
                    SizedBox(width: 3),
                    Text('98% helpful', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text('Today · 10:24 AM', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  );
                }
                return _bubble(_messages[i - 1]);
              },
            ),
          ),
          if (_agentTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Aisha is typing…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: InkWell(
              onTap: _callSupport,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.call, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Call support now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('Speak to an agent in under a minute', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: const Text('<1 min', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_SupportMessage m) {
    final isUser = m.sender == _Sender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          m.text,
          style: TextStyle(fontSize: 13.5, height: 1.4, color: isUser ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}
