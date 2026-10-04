import '../models/chat_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// A lawyer Legal Saathi suggests, with the reason shown on their card.
class SuggestedLawyer {
  const SuggestedLawyer({required this.lawyer, required this.reason});
  final LawyerSummary lawyer;
  final String reason;
}

/// One Legal Saathi answer: the reply text and up to 3 suggested lawyers.
class SaathiAnswer {
  const SaathiAnswer({required this.reply, this.practiceArea = '', this.lawyers = const []});
  final String reply;
  final String practiceArea;
  final List<SuggestedLawyer> lawyers;
}

/// Legal Saathi (AI): the server reads the problem and suggests Vakil lawyers
/// from their practice areas, ratings, reviews, experience and price.
class LegalSaathiService {
  LegalSaathiService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;

  /// [history] is the earlier turns: `{'role': 'user' | 'assistant', 'text': ...}`.
  Future<SaathiAnswer> ask(String message, {List<Map<String, String>> history = const []}) async {
    final data = await api.post('/api/ai/lawyer-suggestions', {'message': message, 'history': history}, token: AuthService.instance.token);
    return SaathiAnswer(
      reply: data['reply']?.toString() ?? '',
      practiceArea: data['practiceArea']?.toString() ?? '',
      lawyers: [
        for (final item in data['lawyers'] as List? ?? const [])
          SuggestedLawyer(lawyer: LawyerSummary.fromJson(Map<String, dynamic>.from(item as Map)), reason: item['reason']?.toString() ?? ''),
      ],
    );
  }
}
