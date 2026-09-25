// Chat data shared with the User App (lib/models/chat_models.dart there).

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
        name: json['name']?.toString() ?? 'Client',
        photoUrl: json['photoUrl'] as String?,
        online: json['online'] == true,
        lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? '')?.toLocal(),
      );
}

/// One row of the chat list (GET /api/chats) and the chat screen header.
class ChatSummary {
  const ChatSummary({required this.requestId, required this.status, required this.other, this.isTrial = false, this.remainingSeconds, this.elapsedSeconds, this.rating, this.lastMessage, this.unread = 0, this.lastActivityAt});
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
    );
  }
}
