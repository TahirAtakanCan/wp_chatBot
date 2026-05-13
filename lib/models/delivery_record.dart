class DeliveryRecord {
  final int id;
  final String phoneNumber;
  final String? contactName;
  final String templateName;
  final String? waMessageId;
  final DeliveryStatus status;
  final String? failureReason;
  final String? failureCode;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? failedAt;
  final String? campaignId;
  final DateTime createdAt;

  DeliveryRecord({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    required this.templateName,
    this.waMessageId,
    required this.status,
    this.failureReason,
    this.failureCode,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failedAt,
    this.campaignId,
    required this.createdAt,
  });

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) {
    return DeliveryRecord(
      id: json['id'] as int,
      phoneNumber: json['phoneNumber'] as String,
      contactName: json['contactName'] as String?,
      templateName: json['templateName'] as String,
      waMessageId: json['waMessageId'] as String?,
      status: DeliveryStatus.values.firstWhere(
        (e) => e.name.toUpperCase() ==
            (json['status'] ?? '').toString().toUpperCase(),
        orElse: () => DeliveryStatus.sent,
      ),
      failureReason: json['failureReason'] as String?,
      failureCode: json['failureCode'] as String?,
      sentAt: DateTime.parse(json['sentAt'] as String),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      failedAt: json['failedAt'] != null
          ? DateTime.parse(json['failedAt'] as String)
          : null,
      campaignId: json['campaignId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

enum DeliveryStatus { sent, delivered, read, failed }
