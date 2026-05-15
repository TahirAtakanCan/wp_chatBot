class Conversation {
  final int id;
  final String phoneNumber;
  final String? contactName;
  final DateTime lastMessageAt;
  final String? lastMessageText;
  final String? lastMessageType;
  final int unreadCount;
  final String status;
  final bool replyWindowOpen;

  Conversation({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    required this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageType,
    required this.unreadCount,
    required this.status,
    required this.replyWindowOpen,
  });

  String get displayName => contactName ?? phoneNumber;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawLastMessageAt =
        json['lastMessageAt']?.toString() ?? DateTime.now().toIso8601String();

    return Conversation(
      id: _toInt(json['id']),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      contactName: json['contactName']?.toString(),
      lastMessageAt: DateTime.parse(rawLastMessageAt),
      lastMessageText: json['lastMessageText']?.toString(),
      lastMessageType: json['lastMessageType']?.toString() ??
          json['last_message_type']?.toString(),
      unreadCount: _toInt(json['unreadCount']),
      status: (json['status'] ?? 'OPEN').toString(),
      replyWindowOpen: _toBool(json['replyWindowOpen']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}