class AuthModel {
  final String token;
  final String role;
  final String username;
  final String? sessionId;

  AuthModel({
    required this.token,
    required this.role,
    required this.username,
    this.sessionId,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    final userNode = json['user'];
    final user = userNode is Map<String, dynamic> ? userNode : null;

    final token = (json['token'] ??
            json['accessToken'] ??
            json['jwt'] ??
            json['access_token'])
        ?.toString();
    final role = (json['role'] ?? user?['role'])?.toString();
    final username = (json['username'] ??
            user?['username'] ??
            user?['name'] ??
            json['name'])
        ?.toString();
    final sessionId =
        (json['sessionId'] ?? json['session_id'] ?? user?['sessionId'])
            ?.toString();

    return AuthModel(
      token: token ?? '',
      role: (role == null || role.isEmpty) ? 'USER' : role,
      username: username ?? '',
      sessionId: (sessionId == null || sessionId.isEmpty) ? null : sessionId,
    );
  }

  bool get isAdmin => role == 'ADMIN';
}
