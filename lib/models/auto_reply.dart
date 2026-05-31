class AutoReply {
  final int id;
  final String category;
  final String keywords;
  final String replyText;
  final bool active;
  final int priority;
  final int matchCount;
  final DateTime createdAt;
  final DateTime? lastMatchedAt;

  AutoReply({
    required this.id,
    required this.category,
    required this.keywords,
    required this.replyText,
    required this.active,
    required this.priority,
    required this.matchCount,
    required this.createdAt,
    this.lastMatchedAt,
  });

  factory AutoReply.fromJson(Map<String, dynamic> json) => AutoReply(
        id: json['id'] as int,
        category: json['category'] as String? ?? '',
        keywords: json['keywords'] as String? ?? '',
        replyText: json['replyText'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        priority: json['priority'] as int? ?? 100,
        matchCount: json['matchCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMatchedAt: json['lastMatchedAt'] != null
            ? DateTime.parse(json['lastMatchedAt'] as String)
            : null,
      );

  List<String> get keywordList =>
      keywords.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
}

class AutoReplySettings {
  final bool enabled;
  final bool useWorkingHours;
  final String workingHoursStart;
  final String workingHoursEnd;
  final String outOfHoursMessage;
  final int cooldownSeconds;

  const AutoReplySettings({
    required this.enabled,
    required this.useWorkingHours,
    required this.workingHoursStart,
    required this.workingHoursEnd,
    required this.outOfHoursMessage,
    required this.cooldownSeconds,
  });

  factory AutoReplySettings.fromJson(Map<String, dynamic> json) {
    return AutoReplySettings(
      enabled: json['enabled'] as bool? ?? true,
      useWorkingHours: json['useWorkingHours'] as bool? ?? false,
      workingHoursStart: json['workingHoursStart'] as String? ?? '09:00',
      workingHoursEnd: json['workingHoursEnd'] as String? ?? '18:00',
      outOfHoursMessage: json['outOfHoursMessage'] as String? ?? '',
      cooldownSeconds: json['cooldownSeconds'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'useWorkingHours': useWorkingHours,
        'workingHoursStart': workingHoursStart,
        'workingHoursEnd': workingHoursEnd,
        'outOfHoursMessage': outOfHoursMessage,
        'cooldownSeconds': cooldownSeconds,
      };

  AutoReplySettings copyWith({
    bool? enabled,
    bool? useWorkingHours,
    String? workingHoursStart,
    String? workingHoursEnd,
    String? outOfHoursMessage,
    int? cooldownSeconds,
  }) {
    return AutoReplySettings(
      enabled: enabled ?? this.enabled,
      useWorkingHours: useWorkingHours ?? this.useWorkingHours,
      workingHoursStart: workingHoursStart ?? this.workingHoursStart,
      workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
      outOfHoursMessage: outOfHoursMessage ?? this.outOfHoursMessage,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    );
  }
}
