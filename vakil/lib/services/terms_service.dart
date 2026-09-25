import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has already agreed to Terms & Privacy — checked once
/// at app launch and persisted locally so this gate only shows on first
/// run, not on every subsequent open.
class TermsService {
  TermsService._();

  static bool agreed = false;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      agreed = prefs.getBool('terms_agreed') ?? false;
    } catch (_) {
      agreed = false;
    }
  }

  static Future<void> setAgreed() async {
    agreed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terms_agreed', true);
    } catch (_) {
      // Local storage unavailable — the in-memory flag still lets this
      // session proceed; it'll just re-ask next launch.
    }
  }
}
