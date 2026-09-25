/// A lawyer as the user sees them: name, photo, categories and availability.
/// The API never sends a lawyer's phone number.
class LawyerSummary {
  const LawyerSummary({required this.id, required this.name, this.photoUrl, this.categories = const [], this.chatOnline = false, this.callOnline = false, this.active = false, this.ratePerMinute = 0, this.callRatePerMinute = 0, this.ratingAverage, this.ratingCount = 0, this.bio = '', this.city = '', this.languages = ''});
  final String id;
  final String name;
  final String? photoUrl;
  final List<String> categories;
  /// Taking chat requests right now (lawyer's "Chat available" switch).
  final bool chatOnline;
  /// Taking voice calls right now ("Call available").
  final bool callOnline;
  /// Taking chats or calls.
  bool get online => chatOnline || callOnline;
  /// Sort key: chat + call first, then chat or call only, then offline.
  int get statusRank => (chatOnline ? 1 : 0) + (callOnline ? 1 : 0);
  /// App open right now.
  final bool active;
  /// Chat price after the free trial, in rupees per minute.
  final double ratePerMinute;
  /// Voice call price per minute (one platform price, ₹40).
  final double callRatePerMinute;
  /// Clients' average rating (1–5) and how many rated; null before the first rating.
  final double? ratingAverage;
  final int ratingCount;
  final String bio;
  final String city;
  final String languages;

  /// The price of a chat, or of a voice call when [call].
  double rateFor({bool call = false}) => call && callRatePerMinute > 0 ? callRatePerMinute : ratePerMinute;

  /// Search: name, practice areas, city and languages.
  bool matchesSearch(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final text = [name, ...categories, city, languages].join(' ').toLowerCase();
    return words.every(text.contains);
  }

  LawyerSummary withStatus({required bool chatOnline, required bool callOnline, required bool active}) => LawyerSummary(
        id: id, name: name, photoUrl: photoUrl, categories: categories, ratePerMinute: ratePerMinute, callRatePerMinute: callRatePerMinute,
        ratingAverage: ratingAverage, ratingCount: ratingCount, bio: bio, city: city, languages: languages,
        chatOnline: chatOnline, callOnline: callOnline, active: active,
      );

  String get category => categories.isEmpty ? 'General' : categories.first;

  factory LawyerSummary.fromJson(Map<String, dynamic> json) => LawyerSummary(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? 'Lawyer',
        photoUrl: json['photoUrl'] as String?,
        categories: (json['categories'] as List? ?? const []).map((c) => c.toString()).toList(),
        // Servers before the Chat/Call switches only sent `online`.
        chatOnline: (json['isChatOnline'] ?? json['online']) == true,
        callOnline: json['isCallOnline'] == true,
        active: json['active'] == true,
        ratePerMinute: (json['ratePerMinute'] as num?)?.toDouble() ?? 0,
        callRatePerMinute: (json['callRatePerMinute'] as num?)?.toDouble() ?? 0,
        ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        bio: json['bio']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        languages: json['languages']?.toString() ?? '',
      );
}

/// A live `lawyer_status_changed` update for one lawyer in a list; the list
/// is re-sorted so online lawyers stay on top.
List<LawyerSummary> applyLawyerStatus(List<LawyerSummary> lawyers, Map<String, dynamic> status) {
  final id = status['id']?.toString();
  final updated = lawyers.map((l) => l.id != id ? l : l.withStatus(chatOnline: status['isChatOnline'] == true, callOnline: status['isCallOnline'] == true, active: status['active'] == true)).toList();
  return sortLawyers(updated);
}

/// Chat + call online first, then chat or call only, then offline; by name within each group.
List<LawyerSummary> sortLawyers(List<LawyerSummary> lawyers) =>
    [...lawyers]..sort((a, b) => b.statusRank.compareTo(a.statusRank) != 0 ? b.statusRank.compareTo(a.statusRank) : a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// sent → delivered → read on the server; pending/failed exist only on this phone.
enum MessageStatus { pending, failed, sent, delivered, read }

class ChatMessage {
  ChatMessage({required this.id, required this.requestId, required this.senderRole, required this.text, required this.createdAt, this.type = 'text', this.status = MessageStatus.sent, this.clientId, this.callStatus});
  /// Server id, or the clientId while the message is still pending.
  String id;
  final String requestId;
  final String senderRole;
  final String text;
  DateTime createdAt;
  final String type;
  MessageStatus status;
  final String? clientId;
  final String? callStatus;

  bool get isCall => type == 'call';
  bool get isPending => status == MessageStatus.pending || status == MessageStatus.failed;

  static MessageStatus parseStatus(String? value) => switch (value) { 'read' => MessageStatus.read, 'delivered' => MessageStatus.delivered, _ => MessageStatus.sent };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'].toString(),
        requestId: json['requestId'].toString(),
        senderRole: json['senderRole']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        type: json['type']?.toString() ?? 'text',
        status: parseStatus(json['status']?.toString()),
        clientId: json['clientId'] as String?,
        callStatus: json['callStatus'] as String?,
      );
}

class ChatPerson {
  const ChatPerson({required this.id, required this.name, this.photoUrl, this.online = false, this.lastSeenAt});
  final String id;
  final String name;
  final String? photoUrl;
  final bool online;
  final DateTime? lastSeenAt;

  factory ChatPerson.fromJson(Map<String, dynamic> json) => ChatPerson(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? 'Lawyer',
        photoUrl: json['photoUrl'] as String?,
        online: json['online'] == true,
        lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? '')?.toLocal(),
      );
}

/// One row of the chat list (GET /api/chats) and the chat screen header.
class ChatSummary {
  const ChatSummary({required this.requestId, required this.status, required this.other, this.isTrial = false, this.remainingSeconds, this.elapsedSeconds, this.rating, this.lastMessage, this.unread = 0, this.lastActivityAt, this.ratePerMinute, this.billedMinutes = 0, this.totalAmount = 0, this.secondsToNextCharge, this.endReason});
  final String requestId;
  final String status;
  final ChatPerson other;
  final bool isTrial;
  final int? remainingSeconds;
  /// Seconds since the chat started (accept), for ongoing chats.
  final int? elapsedSeconds;
  final int? rating;
  final ChatMessage? lastMessage;
  final int unread;
  final DateTime? lastActivityAt;
  /// Paid chats: price, minutes charged so far and their total.
  final double? ratePerMinute;
  final int billedMinutes;
  final double totalAmount;
  final int? secondsToNextCharge;
  /// e.g. balance_over, time_over, ended_by_user.
  final String? endReason;

  bool get isPaid => !isTrial && (ratePerMinute ?? 0) > 0;
  bool get isOngoing => status == 'ONGOING';

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return ChatSummary(
      requestId: json['requestId'].toString(),
      status: json['status']?.toString() ?? 'ONGOING',
      other: ChatPerson.fromJson(Map<String, dynamic>.from(json['other'] as Map)),
      isTrial: json['isTrial'] == true,
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt(),
      lastMessage: last == null ? null : ChatMessage.fromJson({...last, 'requestId': json['requestId']}),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      lastActivityAt: DateTime.tryParse(json['lastActivityAt']?.toString() ?? '')?.toLocal(),
      ratePerMinute: (json['ratePerMinute'] as num?)?.toDouble(),
      billedMinutes: (json['billedMinutes'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      secondsToNextCharge: (json['secondsToNextCharge'] as num?)?.toInt(),
      endReason: json['endReason']?.toString(),
    );
  }
}
