import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../state/wallet_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import 'call_ended_low_balance_screen.dart';
import 'call_ended_success_screen.dart';

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key, required this.lawyer});

  final Lawyer lawyer;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  double _deducted = 0;
  bool _muted = false;
  bool _speaker = false;
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
        _endCall(lowBalance: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _endCall({bool lowBalance = false}) {
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
                isVoiceCall: true,
              )
            : CallEndedSuccessScreen(
                lawyer: widget.lawyer,
                elapsedSeconds: _elapsedSeconds,
                totalCost: _deducted,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calls', style: AppText.h1(AppColors.textDark)),
                        Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 12, color: AppColors.textGray),
                            const SizedBox(width: 4),
                            Text('Privacy mode on',
                                style: AppText.bodySmall(AppColors.textGray)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.blueSoft,
                    child: Text(widget.lawyer.initials,
                        style: AppText.bodyMedium(AppColors.blueAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.splashBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Privacy mode on',
                              style: AppText.caption(Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(widget.lawyer.initials,
                          style: AppText.h1(AppColors.splashBlue)),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.lawyer.name,
                        style: AppText.h2(Colors.white)),
                    const SizedBox(height: 2),
                    Text(widget.lawyer.specialty,
                        style: AppText.bodySmall(
                            Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 18),
                    _Waveform(),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatColumn(
                            label: 'Duration',
                            value: formatMinutesSeconds(_elapsedSeconds)),
                        _StatColumn(
                            label: 'Connection', value: 'Excellent'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundToggle(
                          icon: _muted ? Icons.mic_off : Icons.mic_none,
                          label: 'Mute',
                          active: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        const SizedBox(width: 24),
                        _RoundToggle(
                          icon: Icons.volume_up_outlined,
                          label: 'Speaker',
                          active: _speaker,
                          onTap: () => setState(() => _speaker = !_speaker),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _endCall(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.call_end, size: 18),
                        label: const Text('End call'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Recent calls', style: AppText.h3(AppColors.textDark)),
              const SizedBox(height: 12),
              const _RecentCallRow(
                  name: 'Jordan Park', meta: 'Yesterday · 06:14', status: 'Connected'),
              const SizedBox(height: 10),
              const _RecentCallRow(
                  name: 'Nina Kim', meta: 'Mon · 12:32', status: 'Missed'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const heights = [8.0, 16.0, 24.0, 14.0, 20.0, 10.0, 18.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: heights
          .map((h) => Container(
                width: 4,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ))
          .toList(),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppText.h3(Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: AppText.caption(Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _RoundToggle extends StatelessWidget {
  const _RoundToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 20,
                color: active ? AppColors.splashBlue : Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppText.caption(Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _RecentCallRow extends StatelessWidget {
  const _RecentCallRow({
    required this.name,
    required this.meta,
    required this.status,
  });

  final String name;
  final String meta;
  final String status;

  @override
  Widget build(BuildContext context) {
    final missed = status == 'Missed';
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.lightSurface,
          child: Icon(Icons.person, size: 18, color: AppColors.textGray),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.bodyMedium(AppColors.textDark)),
              Text(meta, style: AppText.caption(AppColors.textGraySoft)),
            ],
          ),
        ),
        Text(status,
            style: AppText.bodySmall(
                missed ? AppColors.redAccent : AppColors.greenAccent)),
      ],
    );
  }
}
