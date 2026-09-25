import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';
import 'active_consultation_chat_screen.dart';
import 'call_receipt_screen.dart';
import 'network_interrupted_screen.dart';

class ConnectedCallScreen extends StatefulWidget {
  final ConsultationRequest request;
  const ConnectedCallScreen({super.key, required this.request});

  @override
  State<ConnectedCallScreen> createState() => _ConnectedCallScreenState();
}

class _ConnectedCallScreenState extends State<ConnectedCallScreen> {
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  int _chatSeconds = 0;
  bool _muted = false;
  bool _speaker = false;
  bool _ended = false;
  bool _interrupted = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ConsultationRequest get r => widget.request;
  int get _remainingSeconds => (r.maxMinutes * 60 - _elapsedSeconds).clamp(0, r.maxMinutes * 60);
  bool get _lowBalance => _remainingSeconds <= 120 && _remainingSeconds > 0;

  @override
  void initState() {
    super.initState();
    _startTicking();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline) {
        _handleNetworkLoss();
      }
    });
  }

  void _startTicking() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _interrupted) return;
      setState(() => _elapsedSeconds++);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _endCall(reason: CallEndReason.lowBalance);
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _handleNetworkLoss() async {
    if (_interrupted || _ended || !mounted) return;
    _interrupted = true;
    final resumed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NetworkInterruptedScreen(), fullscreenDialog: true),
    );
    if (!mounted) return;
    _interrupted = false;
    if (resumed != true) {
      _endCall(reason: CallEndReason.networkFailure);
    }
  }

  void _openChat() async {
    final chatStart = DateTime.now();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActiveConsultationChatScreen(requestId: r.id, title: r.clientName)),
    );
    if (!mounted) return;
    setState(() => _chatSeconds += DateTime.now().difference(chatStart).inSeconds);
  }

  void _showKeypad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.callSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 14,
          children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#']
              .map((digit) => InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sent DTMF tone: $digit'), duration: const Duration(milliseconds: 600)),
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.callBackground, shape: BoxShape.circle),
                      child: Text(digit, style: const TextStyle(color: Colors.white, fontSize: 20)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _confirmEndCall() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End call?'),
        content: Text('End the call with ${r.clientName} now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('End Call'),
          ),
        ],
      ),
    );
    if (confirmed == true) _endCall(reason: CallEndReason.manual);
  }

  void _endCall({required CallEndReason reason}) {
    if (_ended) return;
    _ended = true;
    _elapsedTimer?.cancel();
    _connectivitySub?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallReceiptScreen(
          request: r,
          callSeconds: _elapsedSeconds,
          chatSeconds: _chatSeconds,
          reason: reason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final min = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    final remMin = _remainingSeconds ~/ 60;
    final remSec = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              if (_lowBalance)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A2E12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6B551F)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE8B84B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Client's balance is low. Call ends in ${remMin}m ${remSec}s.",
                          style: const TextStyle(color: Color(0xFFE8B84B), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'SECURE LINE CONNECTED',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4),
              ),
              const SizedBox(height: 10),
              Text(r.clientName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '$min:$sec (₹${r.pricePerMinute}/min)',
                style: const TextStyle(color: AppColors.callTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.signal_cellular_alt, size: 14, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('Connection Status: Excellent', style: TextStyle(color: AppColors.callTextSecondary, fontSize: 11.5)),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _muted ? Icons.mic_off : Icons.mic_none,
                    label: 'Mute',
                    active: _muted,
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  _controlButton(
                    icon: Icons.volume_up_outlined,
                    label: 'Speaker',
                    active: _speaker,
                    onTap: () => setState(() => _speaker = !_speaker),
                  ),
                  _controlButton(icon: Icons.chat_bubble_outline, label: 'Chat', onTap: _openChat),
                  _controlButton(icon: Icons.dialpad, label: 'Keypad', onTap: _showKeypad),
                ],
              ),
              const SizedBox(height: 30),
              Column(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _confirmEndCall,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('End Call', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({required IconData icon, required String label, required VoidCallback onTap, bool active = false}) {
    return Column(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? Colors.white : AppColors.callSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.callBorder),
            ),
            child: Icon(icon, color: active ? AppColors.callBackground : Colors.white, size: 20),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: AppColors.callTextSecondary, fontSize: 11)),
      ],
    );
  }
}

enum CallEndReason { manual, lowBalance, networkFailure }
