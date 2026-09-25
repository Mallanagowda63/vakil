import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_models.dart';
import 'partner_auth_service.dart';

/// REST calls for requests and chats. Live updates come from RealtimeService;
/// these calls are the source of truth after a reconnect.
class PartnerConsultationService {
  Future<Map<String, dynamic>> list(String token) => _get('/api/consultations?status=PENDING', token);
  Future<Map<String, dynamic>> accept(String id, String token) => _post('/api/consultations/$id/accept', token);
  Future<Map<String, dynamic>> reject(String id, String token) => _post('/api/consultations/$id/reject', token);
  Future<Map<String, dynamic>> complete(String id, String token, {num amount = 0}) => _post('/api/consultations/$id/complete', token, {'amount': amount});
  Future<Map<String, dynamic>> presence(String token, bool online) => _patch('/api/lawyers/me/presence', token, {'online': online});
  /// The "Chat available" / "Call available" switches and what the admin allows.
  Future<Map<String, dynamic>> getAvailability(String token) => _get('/api/lawyers/me/presence', token);
  Future<Map<String, dynamic>> setAvailability(String token, {required bool chat, required bool call}) => _patch('/api/lawyers/me/presence', token, {'isChatOnline': chat, 'isCallOnline': call});
  Future<Map<String, dynamic>> getRequest(String id, String token) => _get('/api/consultations/$id', token);
  Future<void> registerDevice(String token, String fcmToken) => _post('/api/devices', token, {'token': fcmToken});
  Future<void> submitRegistration(String token, Map<String, dynamic> body) => _post('/api/lawyers/me/registration', token, body);
  /// What the lawyer earned (client payments minus commission): today's numbers, balance, recent entries.
  Future<Map<String, dynamic>> earnings(String token) => _get('/api/lawyers/me/earnings', token);
  /// Queues the available balance as a payout; the response is the updated summary plus `payout`.
  Future<Map<String, dynamic>> requestPayout(String token) => _post('/api/lawyers/me/payouts', token);

  /// The lawyer's registration details and photo (GET/PATCH /api/profile).
  Future<Map<String, dynamic>> profile(String token) async => Map<String, dynamic>.from((await _get('/api/profile', token))['profile'] as Map);
  Future<Map<String, dynamic>> updateProfile(String token, Map<String, String> fields) async => Map<String, dynamic>.from((await _patch('/api/profile', token, fields))['profile'] as Map);
  Future<Map<String, dynamic>> uploadPhoto(String token, String base64Image, String contentType) async =>
      Map<String, dynamic>.from((await _post('/api/profile/photo', token, {'image': base64Image, 'contentType': contentType}))['profile'] as Map);
  Future<Map<String, dynamic>> removePhoto(String token) async => Map<String, dynamic>.from((await _request(() => http.delete(Uri.parse('${ApiConfig.baseUrl}/api/profile/photo'), headers: _headers(token))))['profile'] as Map);

  /// Feedback after a chat or call: the lawyer rates the client.
  Future<Map<String, dynamic>> review(String id, String token, int rating, String comment) => _post('/api/consultations/$id/review', token, {'rating': rating, 'comment': comment});
  /// Both sides' feedback for one consultation: { mine, theirs }.
  Future<Map<String, dynamic>> feedbackFor(String id, String token) => _get('/api/feedback/consultation/$id', token);
  /// All feedback: { given, received, stats }.
  Future<Map<String, dynamic>> feedback(String token) => _get('/api/feedback', token);

  Future<List<ChatSummary>> chats(String token) async => ((await _get('/api/chats', token))['items'] as List? ?? const [])
      .map((item) => ChatSummary.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  Future<ChatSummary> chat(String id, String token) async => ChatSummary.fromJson(Map<String, dynamic>.from((await _get('/api/chats/$id', token))['chat'] as Map));

  /// Latest page, an older page ([before] = oldest message id), or everything after [after].
  Future<({List<ChatMessage> items, bool hasMore})> messages(String id, String token, {String? before, String? after}) async {
    final query = before != null ? '?before=$before' : after != null ? '?after=$after' : '';
    final data = await _get('/api/consultations/$id/messages$query', token);
    final items = (data['items'] as List? ?? const []).map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    return (items: items, hasMore: data['hasMore'] == true);
  }

  Future<Map<String, dynamic>> _get(String path, String token) => _request(() => http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers(token)));
  Future<Map<String, dynamic>> _post(String path, String token, [Map<String, dynamic> body = const {}]) => _request(() => http.post(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers(token), body: jsonEncode(body)));
  Future<Map<String, dynamic>> _patch(String path, String token, Map<String, dynamic> body) => _request(() => http.patch(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers(token), body: jsonEncode(body)));
  Map<String, String> _headers(String token) => {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};

  Future<Map<String, dynamic>> _request(Future<http.Response> Function() send, {bool retried = false}) async {
    final usedUrl = ApiConfig.baseUrl;
    try {
      final response = await send().timeout(ApiConfig.requestTimeout);
      final data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) throw PartnerNetworkException(data['error']?.toString() ?? 'Request failed. Please try again.', statusCode: response.statusCode);
      return data;
    } on PartnerNetworkException {
      rethrow;
    } on FormatException catch (error, stack) {
      debugPrint('Partner API response error: $error\n$stack');
      throw const PartnerNetworkException('Server returned an invalid response');
    } on Exception catch (error, stack) {
      if (!(error is TimeoutException || error is SocketException || error is http.ClientException)) rethrow;
      debugPrint('Partner API network error: $error\n$stack');
      // The laptop may have a new address: find it and try once more there.
      if (!retried && await ApiConfig.findServer() && ApiConfig.baseUrl != usedUrl) return _request(send, retried: true);
      throw const PartnerNetworkException(ApiConfig.unreachableMessage);
    }
  }
}
