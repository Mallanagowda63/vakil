import 'package:flutter/material.dart';

/// Controls the app's light/dark ThemeMode. Toggling this switches native
/// Material chrome (app bars, dialogs, inputs, switches, status bar) app-wide
/// immediately; screens with their own fixed light styling keep that look.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;

  bool get isDark => mode == ThemeMode.dark;

  void setDark(bool value) {
    mode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
