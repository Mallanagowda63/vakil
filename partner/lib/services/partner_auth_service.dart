import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'realtime_service.dart';

class PartnerNetworkException implements Exception {
  const PartnerNetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override String toString() => message;
}

/// Lawyer sign-in with the registered +91 mobile number and a 6-digit OTP.
class PartnerAuthService {
  PartnerAuthService._();
  static final instance = PartnerAuthService._();
  String? token;
  String? phone;

  /// Restores a saved session; false means the lawyer must sign in again.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('partner_auth_token');
      if (saved == null) return false;
      final res = await _call('GET', '/api/auth/session', token: saved);
      token = saved;
      phone = (res['user'] as Map?)?['phone']?.toString() ?? prefs.getString('partner_phone');
      RealtimeService.instance.connect(saved);
      return true;
    } on PartnerNetworkException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) await logout();
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sends the code. In development (no SMS provider yet) the reply includes it as devCode.
  Future<Map<String, dynamic>> requestOtp(String mobile) => _call('POST', '/api/auth/otp/request', body: {'phone': mobile, 'role': 'lawyer'});

  Future<void> verifyOtp(String mobile, String code) async {
    final res = await _call('POST', '/api/auth/otp/verify', body: {'phone': mobile, 'role': 'lawyer', 'code': code});
    token = res['token'] as String;
    phone = (res['user'] as Map?)?['phone']?.toString() ?? '+91$mobile';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('partner_auth_token', token!);
    await prefs.setString('partner_phone', phone!);
    RealtimeService.instance.connect(token!);
  }

  Future<void> logout() async {
    token = null;
    phone = null;
    RealtimeService.instance.disconnect();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('partner_auth_token');
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
      throw const PartnerNetworkException(ApiConfig.unreachableMessage);
    }
  }
}
