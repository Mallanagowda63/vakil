import 'package:shared_preferences/shared_preferences.dart';
import '../state/free_trial_state.dart';
import 'api_client.dart';
import 'profile_service.dart';
import 'push_service.dart';
import 'wallet_service.dart';
import '../state/wallet_state.dart';
import 'realtime_service.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  final _api = ApiClient();

  String? token;
  /// The sign-in email; [phone] is optional contact info from the profile.
  String? email;
  String? phone;
  bool profileComplete = false;
  bool trialUsed = false;
  Map<String, dynamic>? profile;
  bool get isLoggedIn => token != null;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
      email = prefs.getString('auth_email');
    } catch (_) { return; }
    if (token == null) return;
    try {
      final res = await _api.get('/api/auth/session', token: token);
      if (res['token'] is String) {
        token = res['token'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token!);
      }
      _applyUser(res['user'] as Map<String, dynamic>);
      RealtimeService.instance.connect(token!);
      PushService.instance.registerDevice(token!);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) await _clearSession();
    }
  }

  /// Emails a 6-digit code. Returns the server's reply; in development (no
  /// email service yet) it includes the code as devCode.
  Future<Map<String, dynamic>> requestOtp(String email) => _api.post('/api/auth/otp/request', {'email': email, 'role': 'user'});

  /// Verifies the code, stores the session and opens the realtime connection.
  Future<void> verifyOtp(String email, String code) async {
    final res = await _api.post('/api/auth/otp/verify', {'email': email, 'role': 'user', 'code': code});
    token = res['token'] as String;
    _applyUser(res['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token!);
    await prefs.setString('auth_email', this.email ?? email);
    RealtimeService.instance.connect(token!);
    PushService.instance.registerDevice(token!);
  }

  Future<void> saveProfile({required String fullName, required String language, required String gender, required String aadhaar, required String email, required String sosContact, String phone = ''}) async {
    final body = {'fullName': fullName, 'language': language, 'gender': gender, 'aadhaar': aadhaar, 'email': email, 'sosContact': sosContact, 'phone': phone};
    await _api.post('/api/profile', body, token: token);
    profileComplete = true;
  }

  Future<void> completeTrial() async {
    trialUsed = true;
    FreeTrialState.used = true;
    try { await _api.post('/api/trial/complete', {}, token: token); } catch (_) {}
  }

  Future<void> logout() => _clearSession();

  Future<void> _clearSession() async {
    token = null; email = null; phone = null; profileComplete = false; trialUsed = false; profile = null; FreeTrialState.used = false;
    RealtimeService.instance.disconnect();
    WalletService.instance.clear();
    ProfileService.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_email');
      await prefs.remove('auth_phone');
    } catch (_) {}
  }

  void _applyUser(Map<String, dynamic> user) {
    email = user['email']?.toString() ?? email;
    phone = user['phone']?.toString();
    profileComplete = user['profileComplete'] as bool? ?? false;
    trialUsed = user['trialUsed'] as bool? ?? false;
    profile = user['profile'] as Map<String, dynamic>?;
    FreeTrialState.used = trialUsed;
    WalletState.balance = (user['walletBalance'] as num?)?.toDouble() ?? 0;
  }
}
