import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../screens/login_otp_screen.dart';
import 'account_gone.dart';
import 'app_keys.dart';
import 'realtime_service.dart';

class PartnerNetworkException implements Exception {
  const PartnerNetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override String toString() => message;
}

/// Lawyer sign-in with an email address and a 6-digit code sent to it.
class PartnerAuthService {
  PartnerAuthService._();
  static final instance = PartnerAuthService._();
  String? token;
  String? email;

  /// Restores a saved session; false means the lawyer must sign in again.
  /// Opens with the saved session and waits at most 2.5 s for the server's
  /// check; a slow or missing network keeps the lawyer signed in and the check
  /// finishes in the background (signing out only if the server says so).
  Future<bool> restore() async {
    final String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString('partner_auth_token');
      if (saved == null) return false;
      token = saved;
      email = prefs.getString('partner_email');
    } catch (_) {
      return false;
    }
    RealtimeService.instance.connect(saved);
    final check = _checkSession(saved);
    return check.timeout(const Duration(milliseconds: 2500), onTimeout: () => true);
  }

  Future<bool> _checkSession(String saved) async {
    try {
      final res = await _call('GET', '/api/auth/session', token: saved);
      email = (res['user'] as Map?)?['email']?.toString() ?? email;
      return true;
    } on PartnerNetworkException catch (error) {
      // Deleted by the admin: AccountGone has already signed out and shows the popup.
      if (token == null) return false;
      if (token != saved || (error.statusCode != 401 && error.statusCode != 403)) return true;
      await logout();
      navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginOtpScreen()), (route) => false);
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Emails the code. In development (no email service yet) the reply includes it as devCode.
  /// An email with no account fails with 404 unless [register] is true (a new registration).
  Future<Map<String, dynamic>> requestOtp(String email, {bool register = false}) =>
      _call('POST', '/api/auth/otp/request', body: {'email': email, 'role': 'lawyer', if (register) 'register': true});

  /// Onboarding: emails a code to confirm the Bar Council number (works before sign-in).
  Future<Map<String, dynamic>> sendBarCode(String email, String barCouncilRegNo) =>
      _call('POST', '/api/lawyers/bar-verification/send', body: {'email': email, 'barCouncilRegNo': barCouncilRegNo});
  Future<void> checkBarCode(String email, String barCouncilRegNo, String code) =>
      _call('POST', '/api/lawyers/bar-verification/check', body: {'email': email, 'barCouncilRegNo': barCouncilRegNo, 'code': code});

  Future<void> verifyOtp(String email, String code) async {
    final res = await _call('POST', '/api/auth/otp/verify', body: {'email': email, 'role': 'lawyer', 'code': code});
    token = res['token'] as String;
    this.email = (res['user'] as Map?)?['email']?.toString() ?? email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('partner_auth_token', token!);
    await prefs.setString('partner_email', this.email!);
    RealtimeService.instance.connect(token!);
  }

  Future<void> logout() async {
    token = null;
    email = null;
    RealtimeService.instance.disconnect();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('partner_auth_token');
      await prefs.remove('partner_email');
      await prefs.remove('partner_phone');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _call(String method, String path, {Map<String, dynamic>? body, String? token, bool retried = false}) async {
    final usedUrl = ApiConfig.baseUrl;
    final uri = Uri.parse('$usedUrl$path');
    final headers = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
    try {
      final response = await (method == 'GET' ? http.get(uri, headers: headers) : http.post(uri, headers: headers, body: jsonEncode(body ?? {}))).timeout(ApiConfig.requestTimeout);
      final data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] == 'account_deleted' && token != null) AccountGone.show();
      if (response.statusCode >= 400) throw PartnerNetworkException(data['error']?.toString() ?? 'Sign in failed. Please try again.', statusCode: response.statusCode);
      return data;
    } on PartnerNetworkException {
      rethrow;
    } on FormatException catch (error, stack) {
      debugPrint('Partner auth response error: $error\n$stack');
      throw const PartnerNetworkException('Server returned an invalid response');
    } on Exception catch (error, stack) {
      if (!(error is TimeoutException || error is SocketException || error is http.ClientException)) rethrow;
      debugPrint('Partner auth network error: $error\n$stack');
      // The laptop may have a new address: find it and try once more there.
      if (!retried && await ApiConfig.findServer() && ApiConfig.baseUrl != usedUrl) return _call(method, path, body: body, token: token, retried: true);
      throw PartnerNetworkException(ApiConfig.unreachableMessage);
    }
  }
}
