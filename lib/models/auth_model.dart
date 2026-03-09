class AuthModel {
  final String token;
  final String role;
  final String? sessionId;
  final String username;

  AuthModel({
    required this.token,
    required this.role,
    this.sessionId,
    required this.username,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      token: json['token'] as String,
      role: json['role'] as String,
      sessionId: json['sessionId'] as String?,
      username: json['username'] as String,
    );
  }

  bool get isAdmin => role == 'ADMIN';
}
