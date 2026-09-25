import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import 'call_ended_low_balance_screen.dart';
import 'call_ended_success_screen.dart';

class _Msg {
  _Msg({required this.text, required this.fromMe});
  final String text;
  final bool fromMe;
}

class ConsultationChatScreen extends StatefulWidget {
  const ConsultationChatScreen({super.key, required this.lawyer});

  final Lawyer lawyer;

  @override
  State<ConsultationChatScreen> createState() =>
      _ConsultationChatScreenState();
}

class _ConsultationChatScreenState extends State<ConsultationChatScreen> {
  late final _messages = <_Msg>[
    _Msg(
      fromMe: false,
      text:
          'I have reviewed your accident location. Are the traffic police '
          'claiming a DUI or alcohol test? Please clarify so I can state '
          'your rights.',
    ),
    _Msg(
      fromMe: true,
      text:
          "No DUI, but they are trying to seize my bike keys arbitrarily. "
          "I've uploaded the vehicle's RC.",
    ),
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _timer;
  int _elapsedSeconds = 0;
  double _deducted = 0;
  bool _ended = false;

  double get _ratePerSecond => widget.lawyer.ratePerMinute / 60;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_ended) return;
    setState(() {
      _elapsedSeconds++;
      final charge = _ratePerSecond.clamp(0, WalletState.balance);
      WalletState.balance -= charge;
      _deducted += charge;
      if (WalletState.balance <= 0) {
        WalletState.balance = 0;
        _endChat(lowBalance: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _endChat({bool lowBalance = false}) {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => lowBalance
            ? CallEndedLowBalanceScreen(
                lawyer: widget.lawyer,
                elapsedSeconds: _elapsedSeconds,
                totalDeducted: _deducted,
                isVoiceCall: false,
              )
            : CallEndedSuccessScreen(
                lawyer: widget.lawyer,
                elapsedSeconds: _elapsedSeconds,
                totalCost: _deducted,
              ),
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _ended) return;
    setState(() => _messages.add(_Msg(text: text, fromMe: true)));
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _ended) return;
      setState(() => _messages.add(_Msg(
            fromMe: false,
            text: "Understood — I'll note that for the record.",
          )));
      _scrollToBottom();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lightStroke)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.blueSoft,
                    child: Text(widget.lawyer.initials,
                        style: AppText.bodyMedium(AppColors.blueAccent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adv. ${widget.lawyer.name}',
                            style: AppText.h3(AppColors.textDark)),
                        Row(
                          children: [
                            Icon(Icons.bolt,
                                size: 12, color: AppColors.greenAccent),
                            const SizedBox(width: 2),
                            Text(
                              'Active consultation • '
                              '${formatMinutesSeconds(_elapsedSeconds)} elapsed',
                              style: AppText.caption(AppColors.greenAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _endChat(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.redAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('End chat',
                          style: AppText.bodySmall(Colors.white)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: AppColors.goldSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Charges apply while chat is active. End chat to stop billing.',
                      style: AppText.caption(AppColors.textGray),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  for (var i = 0; i < _messages.length; i++) ...[
                    _Bubble(fromMe: _messages[i].fromMe, text: _messages[i].text),
                    const SizedBox(height: 10),
                    if (i == 1) ...[
                      const _FileBubble(),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.lightStroke)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: !_ended,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: AppText.body(AppColors.textDark),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Reply to Adv. ${widget.lawyer.name}...',
                          hintStyle: AppText.body(AppColors.textGraySoft),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromMe, required this.text});
  final bool fromMe;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: fromMe ? AppColors.textDark : AppColors.lightSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromMe ? 16 : 4),
            bottomRight: Radius.circular(fromMe ? 4 : 16),
          ),
        ),
        child: Text(text,
            style: AppText.body(fromMe ? Colors.white : AppColors.textDark)),
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 20, color: AppColors.blueAccent),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RC_Bike_GJ01.pdf',
                    style: AppText.bodyMedium(AppColors.textDark)),
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 12, color: AppColors.greenAccent),
                    const SizedBox(width: 3),
                    Text('Uploaded to advocate vault',
                        style: AppText.caption(AppColors.textGray)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
