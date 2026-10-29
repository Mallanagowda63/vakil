// Chat data shared with the User App (lib/models/chat_models.dart there).

/// sent → delivered → read on the server; pending/failed exist only on this phone.
enum MessageStatus { pending, failed, sent, delivered, read }

class ChatMessage {
  ChatMessage({required this.id, required this.requestId, required this.senderRole, required this.text, required this.createdAt, this.type = 'text', this.status = MessageStatus.sent, this.clientId, this.callStatus, this.attachment});
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
  /// The photo or file of an 'image' / 'file' message.
  final ChatAttachment? attachment;

  bool get isCall => type == 'call';
  bool get isImage => type == 'image' && attachment != null;
  bool get isFile => type == 'file' && attachment != null;
  bool get isVoice => type == 'audio' && attachment != null;
  /// A photo or file the server has not deleted yet.
  bool get hasLiveAttachment => attachment != null && !attachment!.deleted;

  /// This message with its file marked deleted (after the 'attachments_deleted' event).
  ChatMessage withAttachmentDeleted() => ChatMessage(id: id, requestId: requestId, senderRole: senderRole, text: text, createdAt: createdAt, type: type, status: status, clientId: clientId, callStatus: callStatus, attachment: attachment?.markDeleted());
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
        attachment: json['attachment'] is Map ? ChatAttachment.fromJson(Map<String, dynamic>.from(json['attachment'] as Map)) : null,
      );
}

/// A photo or file sent in a chat; the bytes are fetched from the server with the sign-in token.
class ChatAttachment {
  const ChatAttachment({required this.id, required this.fileName, required this.contentType, required this.size, this.deleted = false, this.durationSeconds});
  final String id;
  final String fileName;
  final String contentType;
  final int size;
  /// The server deletes chat files 5 minutes after the chat ends.
  final bool deleted;
  /// Length of a voice message.
  final int? durationSeconds;

  ChatAttachment markDeleted() => ChatAttachment(id: id, fileName: fileName, contentType: contentType, size: size, deleted: true, durationSeconds: durationSeconds);

  String get sizeLabel => size >= 1024 * 1024 ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB' : '${(size / 1024).ceil()} KB';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        id: json['id'].toString(),
        fileName: json['fileName']?.toString() ?? 'File',
        contentType: json['contentType']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        deleted: json['deleted'] == true,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
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
  const ChatSummary({required this.requestId, required this.status, required this.other, this.isTrial = false, this.remainingSeconds, this.elapsedSeconds, this.rating, this.lastMessage, this.unread = 0, this.lastActivityAt, this.consultationType = 'chat', this.category = '', this.totalAmount = 0, this.billedMinutes = 0});
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
  final String category;
  /// What the client paid for this chat, and the minutes charged.
  final double totalAmount;
  final int billedMinutes;

  bool get isOngoing => status == 'ONGOING';
  /// 'chat' or 'call': a chat consultation has no call button and a call
  /// consultation has no message box.
  final String consultationType;
  bool get isCall => consultationType == 'call';

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
      consultationType: json['consultationType']?.toString() ?? 'chat',
      category: json['category']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      billedMinutes: (json['billedMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}
