import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override String toString() => message;
}

class ApiClient {
  ApiClient({this._baseUrl});
  final String? _baseUrl;
  String get baseUrl => _baseUrl ?? ApiConfig.baseUrl;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token}) =>
      _request(() => http.post(Uri.parse('$baseUrl$path'), headers: _headers(token), body: jsonEncode(body)));

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      _request(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers(token)));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body, {String? token}) =>
      _request(() => http.patch(Uri.parse('$baseUrl$path'), headers: _headers(token), body: jsonEncode(body)));

  Future<Map<String, dynamic>> delete(String path, {String? token}) =>
      _request(() => http.delete(Uri.parse('$baseUrl$path'), headers: _headers(token)));

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _request(Future<http.Response> Function() send, {bool retried = false}) async {
    final usedUrl = baseUrl;
    try {
      final response = await send().timeout(ApiConfig.requestTimeout);
      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}
      if (response.statusCode >= 400) throw ApiException(data['error']?.toString() ?? 'Request failed. Please try again.', statusCode: response.statusCode);
      return data;
    } on Exception catch (error, stack) {
      if (error is ApiException || !(error is TimeoutException || error is SocketException || error is http.ClientException)) rethrow;
      debugPrint('Network error: $error\n$stack');
      // The laptop may have a new address: find it and try once more there.
      if (!retried && _baseUrl == null && await ApiConfig.findServer() && ApiConfig.baseUrl != usedUrl) return _request(send, retried: true);
      throw const ApiException(ApiConfig.unreachableMessage);
    }
  }
}
