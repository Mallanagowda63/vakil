import '../models/chat_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// REST calls for lawyers, requests and chats. Live updates come from
/// RealtimeService; these calls are the source of truth after a reconnect.
class ConsultationService {
  ConsultationService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  String? get _token => AuthService.instance.token;

  Future<List<LawyerSummary>> lawyers() async => ((await api.get('/api/lawyers', token: _token))['items'] as List? ?? const [])
      .map((item) => LawyerSummary.fromJson(Map<String, dynamic>.from(item as Map))).toList();

  /// [consultationType] 'call' asks for a call: the chat opens on accept and the call starts.
  /// [minutes]: the time bought for a paid chat (null for the free trial).
  Future<Map<String, dynamic>> create({String? lawyerId, required String category, String description = '', String consultationType = 'chat', int? minutes}) async =>
      Map<String, dynamic>.from((await api.post('/api/consultations', {'category': category, 'consultationType': consultationType, 'description': description, 'lawyerId': ?lawyerId, 'minutes': ?minutes}, token: _token))['request'] as Map);
  /// Buys [minutes] more for an ongoing chat; returns the new `remainingSeconds`.
  Future<int> addTime(String id, int minutes) async => ((await api.post('/api/consultations/$id/extend', {'minutes': minutes}, token: _token))['remainingSeconds'] as num).toInt();
  Future<void> cancel(String id) async { await api.post('/api/consultations/$id/cancel', {}, token: _token); }
  Future<Map<String, dynamic>> getRequest(String id) async => Map<String, dynamic>.from((await api.get('/api/consultations/$id', token: _token))['request'] as Map);

  Future<List<ChatSummary>> chats() async => ((await api.get('/api/chats', token: _token))['items'] as List? ?? const [])
      .map((item) => ChatSummary.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  Future<ChatSummary> chat(String id) async => ChatSummary.fromJson(Map<String, dynamic>.from((await api.get('/api/chats/$id', token: _token))['chat'] as Map));

  /// Latest page, an older page ([before] = oldest message id), or everything after [after].
  Future<({List<ChatMessage> items, bool hasMore})> messages(String id, {String? before, String? after}) async {
    final query = before != null ? '?before=$before' : after != null ? '?after=$after' : '';
    final data = await api.get('/api/consultations/$id/messages$query', token: _token);
    final items = (data['items'] as List? ?? const []).map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    return (items: items, hasMore: data['hasMore'] == true);
  }

  Future<void> endChat(String id) async { await api.post('/api/consultations/$id/complete', {}, token: _token); }
  Future<void> review(String id, int rating, String comment) async { await api.post('/api/consultations/$id/review', {'rating': rating, 'comment': comment}, token: _token); }
}
