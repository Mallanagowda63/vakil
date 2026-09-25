import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'partner_settings.dart';

/// In-app sounds for the lawyer: a loud looping ring with vibration while a
/// request waits, and a short "ding" for new messages. Both follow the
/// Sound and Vibration switches in Settings.
class AlertService {
  AlertService._();
  static final instance = AlertService._();

  final _ring = AudioPlayer(playerId: 'request_ring');
  final _ding = AudioPlayer(playerId: 'message_ding');
  Timer? _vibrationLoop;
  bool ringing = false;

  PartnerSettings get _settings => PartnerSettings.instance;

  Future<void> init() async {
    // Alerts should sound like a phone ringing, even over other audio.
    await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.gain).build());
    await _ring.setReleaseMode(ReleaseMode.loop);
    await _ding.setReleaseMode(ReleaseMode.stop);
    _settings.addListener(() { if (ringing) { stopRequestRing(); startRequestRing(); } });
  }

  /// Rings until [stopRequestRing] (accepted, rejected, expired or cancelled).
  Future<void> startRequestRing() async {
    if (ringing) return;
    ringing = true;
    try {
      if (_settings.soundOn) {
        await _ring.setVolume(1.0);
        await _ring.play(AssetSource('sounds/request_ring.mp3'));
      }
      if (_settings.vibrationOn && await Vibration.hasVibrator()) {
        // Vibrate in step with the 1.8 s ring: buzz, pause, buzz, pause.
        Vibration.vibrate(pattern: [0, 400, 200, 400, 800]);
        _vibrationLoop = Timer.periodic(const Duration(milliseconds: 1800), (_) => Vibration.vibrate(pattern: [0, 400, 200, 400]));
      }
    } catch (error) {
      debugPrint('Request ring failed: $error');
    }
  }

  Future<void> stopRequestRing() async {
    if (!ringing) return;
    ringing = false;
    _vibrationLoop?.cancel();
    _vibrationLoop = null;
    try {
      await _ring.stop();
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Short ding with a light buzz; [soft] when the lawyer already has that chat open.
  Future<void> messageDing({bool soft = false}) async {
    if (ringing) return;
    try {
      if (_settings.soundOn) {
        await _ding.stop();
        await _ding.setVolume(soft ? 0.25 : 0.9);
        await _ding.play(AssetSource('sounds/message.mp3'));
      }
      if (!soft && _settings.vibrationOn && await Vibration.hasVibrator()) Vibration.vibrate(duration: 60, amplitude: 80);
    } catch (error) {
      debugPrint('Message ding failed: $error');
    }
  }
}
