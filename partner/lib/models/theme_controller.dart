import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark appearance (Home's sun/moon button and Settings); remembered on this phone.
class ThemeController extends ChangeNotifier {
  ThemeController() { _load(); }
  static const _key = 'partner_dark_mode';
  ThemeMode mode = ThemeMode.light;

  bool get isDark => mode == ThemeMode.dark;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) == true) { mode = ThemeMode.dark; notifyListeners(); }
    } catch (_) {}
  }

  void setDark(bool value) {
    mode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_key, value)).catchError((_) => false);
  }
}
