import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/call_service.dart';

/// The voice call on screen: "Calling…" → "Ringing…" while the other phone
/// rings, then the talk timer with mute, speaker and end. Incoming calls ring
/// on the phone's native call screen and open this one once accepted.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.session});
  final CallSession session;
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _muted = Color(0xFF94A3B8);
  late final Timer _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });

  CallSession get _call => widget.session;

  @override
  void initState() {
    super.initState();
    _call.addListener(_changed);
  }

  @override
  void dispose() {
    _call.removeListener(_changed);
    _ticker.cancel();
    super.dispose();
  }

  void _changed() { if (mounted) setState(() {}); }

  static String _clock(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  String get _status => switch (_call.phase) {
    CallPhase.calling => 'Calling…',
    CallPhase.ringing => 'Ringing…',
    CallPhase.connecting => 'Connecting…',
    CallPhase.active => _clock(_call.talkSeconds),
    CallPhase.ended => _call.endMessage ?? 'Call ended',
  };

  @override
  Widget build(BuildContext context) {
    final ended = _call.phase == CallPhase.ended;
    final left = _call.secondsLeft;
    final photo = _call.otherPhotoUrl;
    final photoUrl = photo == null || photo.isEmpty ? null : photo.startsWith('/') ? '${ApiConfig.baseUrl}$photo' : photo;
    final initial = _call.otherName.trim().isEmpty ? '?' : _call.otherName.trim()[0].toUpperCase();
    // Back does not drop the call; End does.
    return PopScope(
      canPop: ended,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(children: [
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 13, color: _muted),
                SizedBox(width: 6),
                Text('Vakil voice call', style: TextStyle(color: _muted, fontSize: 12.5, letterSpacing: 0.3)),
              ]),
              const Spacer(),
              CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFF3B5BDB),
                foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
                child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 20),
              Text(_call.otherName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_status, style: TextStyle(color: ended ? const Color(0xFFFCA5A5) : _muted, fontSize: 16, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 14),
              // The call ends with the chat; show how long is left.
              if (!ended && left != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: left <= 30 ? const Color(0xFF7F1D1D) : _surface, borderRadius: BorderRadius.circular(20)),
                  child: Text('Time left ${_clock(left)}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              // The last minute: the call ends with the chat unless the client adds time.
              if (!ended && left != null && left <= 60) ...[
                const SizedBox(height: 14),
                const Text('Less than 1 minute left. The client can add more time.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
              ],
              const Spacer(),
              if (!ended)
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _RoundButton(icon: _call.muted ? Icons.mic_off : Icons.mic_none, label: _call.muted ? 'Unmute' : 'Mute', active: _call.muted, onTap: CallService.instance.toggleMute),
                  _RoundButton(icon: Icons.call_end, label: 'End', color: const Color(0xFFDC2626), onTap: CallService.instance.hangUp, size: 68),
                  _RoundButton(icon: _call.speaker ? Icons.volume_up : Icons.volume_down_outlined, label: 'Speaker', active: _call.speaker, onTap: CallService.instance.toggleSpeaker),
                ])
              else
                const SizedBox(height: 96),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.color, this.active = false, this.size = 58});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = color ?? (active ? Colors.white : const Color(0xFF1E293B));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: active && color == null ? const Color(0xFF0F172A) : Colors.white, size: 26)),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]);
  }
}
