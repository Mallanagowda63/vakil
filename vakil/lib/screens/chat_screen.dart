import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'paid_version_screen.dart';

class _Message {
  _Message({required this.text, required this.fromMe, required this.time});
  final String text;
  final bool fromMe;
  final String time;
}

const _sessionSeconds = 60;

const _autoReplies = [
  "Got it, thanks for clarifying!",
  "Noted — I'll factor that in.",
  "Sounds good, checking on that now.",
  "Perfect, I'll update the doc accordingly.",
  "Makes sense, give me a moment.",
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <_Message>[
    _Message(
      fromMe: false,
      time: '10:24 AM',
      text:
          'Hey! I put together a first pass of the onboarding flow. Want me to share it now?',
    ),
    _Message(
      fromMe: true,
      time: '10:25 AM',
      text:
          "Yes please - drop the link here and I'll review it with the team.",
    ),
    _Message(
      fromMe: false,
      time: '10:25 AM',
      text:
          "Perfect. I'm attaching the prototype plus a quick note on the empty state.",
    ),
    _Message(
      fromMe: true,
      time: '10:27 AM',
      text: "Awesome, thank you. I'll leave comments inline.",
    ),
  ];

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _timer;
  int _secondsLeft = _sessionSeconds;
  int _replyIndex = 0;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        AuthService.instance.completeTrial();
        setState(() {
          _secondsLeft = 0;
          _sessionEnded = true;
        });
        _goToPaywall();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _goToPaywall() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PaidVersionScreen()),
      );
    });
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _nowLabel() {
    final now = TimeOfDay.now();
    final hour12 = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sessionEnded) return;

    setState(() {
      _messages.add(_Message(text: text, fromMe: true, time: _nowLabel()));
    });
    _inputController.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || _sessionEnded) return;
      setState(() {
        _messages.add(
          _Message(
            text: _autoReplies[_replyIndex % _autoReplies.length],
            fromMe: false,
            time: _nowLabel(),
          ),
        );
        _replyIndex++;
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              timerLabel: _timerLabel,
              urgent: _secondsLeft <= 10,
              onCall: () => _showSnack('Calling Maya Chen…'),
              onEndChat: _sessionEnded
                  ? null
                  : () {
                      _timer?.cancel();
                      AuthService.instance.completeTrial();
                      setState(() => _sessionEnded = true);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const PaidVersionScreen()),
                      );
                    },
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Center(
                    child: Text('Today',
                        style: AppText.bodySmall(AppColors.textGraySoft)),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _messages.length; i++) ...[
                    if (i == 3)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _FileBubble(
                            onTap: () =>
                                _showSnack('Opening onboarding-flow.fig…'),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChatBubble(
                        fromMe: _messages[i].fromMe,
                        text: _messages[i].text,
                        time: _messages[i].time,
                      ),
                    ),
                  ],
                  if (_sessionEnded)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'Free session ended',
                          style: AppText.bodySmall(AppColors.textGraySoft),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _ChatInputBar(
              controller: _inputController,
              enabled: !_sessionEnded,
              onSend: _send,
              onAttach: () => _showSnack('Attachments coming soon'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.timerLabel,
    required this.urgent,
    required this.onCall,
    required this.onEndChat,
  });

  final String timerLabel;
  final bool urgent;
  final VoidCallback onCall;
  final VoidCallback? onEndChat;

  @override
  Widget build(BuildContext context) {
    final timerColor = urgent ? AppColors.redAccent : AppColors.textGray;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lightStroke)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.blueSoft,
            child: Icon(Icons.person, color: AppColors.blueAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maya Chen', style: AppText.h3(AppColors.textDark)),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Online now',
                        style: AppText.bodySmall(AppColors.greenAccent)),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: timerColor),
              const SizedBox(width: 4),
              Text(timerLabel,
                  style: AppText.bodySmall(timerColor)
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          IconButton(
            onPressed: onCall,
            icon: Icon(Icons.call_outlined, color: AppColors.textDark),
          ),
          IconButton(
            onPressed: onEndChat,
            icon: Icon(Icons.more_vert, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.fromMe,
    required this.text,
    required this.time,
  });

  final bool fromMe;
  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    final bg = fromMe ? AppColors.blueAccent : AppColors.lightSurface;
    final fg = fromMe ? Colors.white : AppColors.textDark;

    return Column(
      crossAxisAlignment:
          fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromMe ? 16 : 4),
                bottomRight: Radius.circular(fromMe ? 4 : 16),
              ),
            ),
            child: Text(text, style: AppText.body(fg)),
          ),
        ),
        const SizedBox(height: 4),
        Text(time, style: AppText.caption(AppColors.textGraySoft)),
      ],
    );
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.insert_drive_file_outlined,
                  size: 18, color: AppColors.blueAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('onboarding-flow.fig',
                      style: AppText.bodyMedium(AppColors.textDark),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('2.4 MB · Prototype',
                      style: AppText.bodySmall(AppColors.textGray)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Ready',
                  style: AppText.caption(AppColors.greenAccent)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.lightStroke)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAttach,
            child: Icon(Icons.add_circle_outline, color: AppColors.textGray),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      style: AppText.body(AppColors.textDark),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText:
                            enabled ? 'Write a message' : 'Session ended',
                        hintStyle: AppText.body(AppColors.textGraySoft),
                      ),
                    ),
                  ),
                  Icon(Icons.emoji_emotions_outlined,
                      size: 18, color: AppColors.textGraySoft),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.blueAccent
                    : AppColors.blueAccent.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
