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
  final String? filename;
  final int? fileSizeBytes;
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
    this.filename,
    this.fileSizeBytes,
    required this.sentAt,
    required this.status,
  });

  bool get isInbound => direction.toUpperCase() == 'INBOUND';
  bool get isOutbound => direction.toUpperCase() == 'OUTBOUND';

  bool get isImage => messageType.toUpperCase() == 'IMAGE';

  bool get hasWaMessageId => (waMessageId ?? '').trim().isNotEmpty;

  bool get isDeliveredStatus {
    switch (status.toUpperCase()) {
      case 'SENT':
      case 'DELIVERED':
      case 'READ':
        return true;
      default:
        return false;
    }
  }

  Message copyWith({
    int? id,
    String? direction,
    String? messageType,
    String? content,
    String? waMessageId,
    String? mediaId,
    String? mediaUrl,
    String? url,
    String? mimeType,
    String? caption,
    String? filename,
    int? fileSizeBytes,
    DateTime? sentAt,
    String? status,
  }) {
    return Message(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      waMessageId: waMessageId ?? this.waMessageId,
      mediaId: mediaId ?? this.mediaId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      url: url ?? this.url,
      mimeType: mimeType ?? this.mimeType,
      caption: caption ?? this.caption,
      filename: filename ?? this.filename,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
    );
  }

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
      filename: json['filename']?.toString(),
      fileSizeBytes: _toOptionalInt(
        json['fileSize'] ?? json['fileSizeBytes'] ?? json['size'],
      ),
      sentAt: DateTime.parse(rawSentAt),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}