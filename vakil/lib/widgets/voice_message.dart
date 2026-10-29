import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import 'app_loader.dart';
import 'chat_attachments.dart';

// Voice messages in a chat, shared by the User App and the Partner App (keep
// both copies of this file identical). Hold the mic to record (up to 2
// minutes), slide left to cancel, let go to send. The recording is AAC (.m4a)
// and is sent like any chat file, so it is private to the chat and deleted
// 5 minutes after the chat ends.

const maxVoiceSeconds = 120;

/// The mic button. Calls [onSent] with the stored message once it is sent.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({super.key, required this.requestId, required this.token, required this.onSent, this.color});
  final String requestId;
  final String? token;
  final ValueChanged<ChatMessage> onSent;
  final Color? color;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final _recorder = AudioRecorder();
  OverlayEntry? _banner;
  Timer? _clock;
  DateTime? _startedAt;
  String? _path;
  bool _cancelled = false;
  bool _sending = false;
  final _seconds = ValueNotifier<int>(0);
  final _slide = ValueNotifier<double>(0);

  @override
  void dispose() {
    _clock?.cancel();
    _banner?.remove();
    _recorder.dispose();
    _seconds.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  Future<void> _start() async {
    if (_sending || _startedAt != null) return;
    if (!await _recorder.hasPermission()) { _say('Allow the microphone to send voice messages.'); return; }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _cancelled = false;
    _slide.value = 0;
    _seconds.value = 0;
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 44100, numChannels: 1), path: _path!);
    } catch (_) {
      _say('Could not start recording.');
      return;
    }
    HapticFeedback.mediumImpact();
    _startedAt = DateTime.now();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final s = DateTime.now().difference(_startedAt!).inSeconds;
      _seconds.value = s;
      if (s >= maxVoiceSeconds) _finish();
    });
    _showBanner();
  }

  Future<void> _finish() async {
    final started = _startedAt;
    if (started == null) return;
    _startedAt = null;
    _clock?.cancel();
    _banner?.remove();
    _banner = null;
    final duration = DateTime.now().difference(started);
    final path = await _recorder.stop();
    final file = path == null ? null : File(path);
    if (_cancelled || file == null) { await _remove(file); return; }
    if (duration.inMilliseconds < 800) { await _remove(file); _say('Hold the mic to record a voice message.'); return; }
    final token = widget.token;
    if (token == null) return;
    setState(() => _sending = true);
    final bytes = await file.readAsBytes();
    final (message, error) = await uploadChatFile(requestId: widget.requestId, token: token, bytes: bytes, contentType: 'audio/mp4', fileName: 'voice.m4a', durationSeconds: duration.inSeconds.clamp(1, maxVoiceSeconds));
    await _remove(file);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) _say(error);
    if (message != null) widget.onSent(message);
  }

  static Future<void> _remove(File? file) async {
    try { await file?.delete(); } catch (_) {}
  }

  void _showBanner() {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    if (box == null) return;
    final bottom = MediaQuery.sizeOf(context).height - box.localToGlobal(Offset.zero).dy + 8;
    _banner = OverlayEntry(builder: (_) => Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<double>(
          valueListenable: _slide,
          builder: (context, slide, child) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: slide > 0.6 ? const Color(0xFFFDECEC) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              const _Pulse(),
              const SizedBox(width: 10),
              ValueListenableBuilder<int>(
                valueListenable: _seconds,
                builder: (context, s, child) => Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}  /  2:00', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFeatures: [FontFeature.tabularFigures()])),
              ),
              const Spacer(),
              Icon(Icons.chevron_left, size: 18, color: slide > 0.6 ? const Color(0xFFDC2626) : Colors.black45),
              Text(slide > 0.6 ? 'Release to cancel' : 'Slide left to cancel', style: TextStyle(fontSize: 12.5, color: slide > 0.6 ? const Color(0xFFDC2626) : Colors.black54, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    ));
    overlay.insert(_banner!);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressMoveUpdate: (d) { _slide.value = (-d.offsetFromOrigin.dx / 140).clamp(0.0, 1.0); _cancelled = _slide.value > 0.6; },
      onLongPressEnd: (_) => _finish(),
      onTap: () => _say('Hold the mic to record, let go to send.'),
      child: ValueListenableBuilder<int>(
        valueListenable: _seconds,
        builder: (context, s, child) {
          final recording = _startedAt != null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: recording ? 56 : 48,
            height: recording ? 56 : 48,
            decoration: BoxDecoration(color: recording ? const Color(0xFFDC2626) : color, shape: BoxShape.circle),
            child: _sending
                ? const Center(child: DotsLoader(size: 5, color: Colors.white))
                : const Icon(Icons.mic_rounded, color: Colors.white),
          );
        },
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: 0.3, end: 1.0).animate(_c), child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle)));
}

/// A voice message in a chat bubble: play / pause, progress and length.
/// Only one plays at a time.
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({super.key, required this.message, required this.token, required this.mine});
  final ChatMessage message;
  final String? token;
  final bool mine;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  static _VoiceBubbleState? _playing;
  AudioPlayer? _player;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _position = Duration.zero;
  Duration? _total;
  bool _loading = false;
  bool _isPlaying = false;

  ChatAttachment get _a => widget.message.attachment!;

  @override
  void dispose() {
    if (_playing == this) _playing = null;
    for (final s in _subs) { s.cancel(); }
    _player?.dispose();
    super.dispose();
  }

  Future<File> _download() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voice_${_a.id}.m4a');
    if (await file.exists()) return file;
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/consultations/${widget.message.requestId}/attachments/${_a.id}'), headers: {if (widget.token != null) 'Authorization': 'Bearer ${widget.token}'}).timeout(const Duration(seconds: 60));
    if (response.statusCode == 404) throw const HttpException('deleted');
    if (response.statusCode != 200) throw const HttpException('failed');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> _toggle() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isPlaying) { await _player?.pause(); return; }
    if (_playing != null && _playing != this) await _playing!._player?.pause();
    _playing = this;
    if (_player == null) {
      setState(() => _loading = true);
      try {
        final file = await _download();
        final player = _player = AudioPlayer();
        _subs.add(player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); }));
        _subs.add(player.onDurationChanged.listen((d) { if (mounted) setState(() => _total = d); }));
        _subs.add(player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _isPlaying = s == PlayerState.playing); }));
        _subs.add(player.onPlayerComplete.listen((_) { if (mounted) setState(() { _position = Duration.zero; _isPlaying = false; }); }));
        await player.setSourceDeviceFile(file.path);
      } on HttpException catch (e) {
        _player = null;
        if (mounted) setState(() => _loading = false);
        messenger.showSnackBar(SnackBar(content: Text(e.message == 'deleted' ? 'This voice message was deleted after the chat ended.' : 'Could not load the voice message. Try again.')));
        return;
      } catch (_) {
        _player = null;
        if (mounted) setState(() => _loading = false);
        messenger.showSnackBar(const SnackBar(content: Text('Could not play the voice message.')));
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    await _player!.resume();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : const Color(0xFF14141F);
    final total = _total ?? Duration(seconds: _a.durationSeconds ?? 0);
    final progress = total.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final shown = _isPlaying || _position > Duration.zero ? _position : total;
    final label = '${shown.inMinutes}:${(shown.inSeconds % 60).toString().padLeft(2, '0')}';
    return SizedBox(
      width: 220,
      child: Row(children: [
        GestureDetector(
          onTap: _loading ? null : _toggle,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: widget.mine ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE8EEFC), shape: BoxShape.circle),
            child: _loading
                ? Center(child: DotsLoader(size: 4, color: widget.mine ? Colors.white : const Color(0xFF2454E0)))
                : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.mine ? Colors.white : const Color(0xFF2454E0)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: fg.withValues(alpha: 0.18), valueColor: AlwaysStoppedAnimation(fg.withValues(alpha: 0.85))),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.mic_rounded, size: 13, color: fg.withValues(alpha: 0.6)),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.75), fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ])),
      ]),
    );
  }
}
