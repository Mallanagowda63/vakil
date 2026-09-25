import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound and vibration switches for alerts, saved on the phone.
class PartnerSettings extends ChangeNotifier {
  PartnerSettings._();
  static final instance = PartnerSettings._();

  bool soundOn = true;
  bool vibrationOn = true;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      soundOn = prefs.getBool('alert_sound') ?? true;
      vibrationOn = prefs.getBool('alert_vibration') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSound(bool value) async { soundOn = value; notifyListeners(); await _save('alert_sound', value); }
  Future<void> setVibration(bool value) async { vibrationOn = value; notifyListeners(); await _save('alert_vibration', value); }

  Future<void> _save(String key, bool value) async {
    try { await (await SharedPreferences.getInstance()).setBool(key, value); } catch (_) {}
  }
}
