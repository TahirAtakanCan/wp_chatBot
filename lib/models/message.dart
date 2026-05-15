import '../utils/message_text_utils.dart';

class Message {
  final int id;
  final String direction;
  final String messageType;
  final String? content;
  final String? waMessageId;
  final String? mediaId;
  final String? mediaUrl;
  final String? url;
  final String? mimeType;
  final String? caption;
  final DateTime sentAt;
  final String status;

  Message({
    required this.id,
    required this.direction,
    required this.messageType,
    this.content,
    this.waMessageId,
    this.mediaId,
    this.mediaUrl,
    this.url,
    this.mimeType,
    this.caption,
    required this.sentAt,
    required this.status,
  });

  bool get isInbound => direction.toUpperCase() == 'INBOUND';
  bool get isOutbound => direction.toUpperCase() == 'OUTBOUND';

  bool get isImage => messageType.toUpperCase() == 'IMAGE';

  String? get effectiveCaption {
    final cap = caption?.trim();
    if (cap != null && cap.isNotEmpty) return cap;
    final body = content?.trim();
    if (body != null && body.isNotEmpty && !isMediaPlaceholderContent(body)) {
      return body;
    }
    return null;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawSentAt =
        json['sentAt']?.toString() ?? DateTime.now().toIso8601String();

    final mediaUrl = json['mediaUrl']?.toString() ?? json['media_url']?.toString();
    final url = json['url']?.toString();

    return Message(
      id: _toInt(json['id']),
      direction: (json['direction'] ?? '').toString().toUpperCase(),
      messageType: (json['messageType'] ?? json['message_type'] ?? 'TEXT')
          .toString()
          .toUpperCase(),
      content: json['content']?.toString(),
      waMessageId: json['waMessageId']?.toString() ?? json['wa_message_id']?.toString(),
      mediaId: json['mediaId']?.toString() ?? json['media_id']?.toString(),
      mediaUrl: mediaUrl,
      url: url,
      mimeType: json['mimeType']?.toString() ?? json['mime_type']?.toString(),
      caption: json['caption']?.toString(),
      sentAt: DateTime.parse(rawSentAt),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}