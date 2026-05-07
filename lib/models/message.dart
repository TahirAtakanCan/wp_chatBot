class Message {
  final int id;
  final String direction;
  final String messageType;
  final String? content;
  final String? waMessageId;
  final DateTime sentAt;
  final String status;

  Message({
    required this.id,
    required this.direction,
    required this.messageType,
    this.content,
    this.waMessageId,
    required this.sentAt,
    required this.status,
  });

  bool get isInbound => direction == 'INBOUND';
  bool get isOutbound => direction == 'OUTBOUND';

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawSentAt =
        json['sentAt']?.toString() ?? DateTime.now().toIso8601String();

    return Message(
      id: _toInt(json['id']),
      direction: (json['direction'] ?? '').toString(),
      messageType: (json['messageType'] ?? '').toString(),
      content: json['content']?.toString(),
      waMessageId: json['waMessageId']?.toString(),
      sentAt: DateTime.parse(rawSentAt),
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}