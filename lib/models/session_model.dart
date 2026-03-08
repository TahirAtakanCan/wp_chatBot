class SessionModel {
  final String sessionId;
  final bool connected;
  final String? user;
  final bool ready;
  final bool hasQR;

  SessionModel({
    required this.sessionId,
    required this.connected,
    this.user,
    required this.ready,
    required this.hasQR,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['sessionId'] as String,
      connected: json['connected'] as bool? ?? false,
      user: json['user'] as String?,
      ready: json['ready'] as bool? ?? false,
      hasQR: json['hasQR'] as bool? ?? false,
    );
  }
}
