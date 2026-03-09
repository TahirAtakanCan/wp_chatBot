/// Lokal/Canlı ortam geçişi için tek şalter.
/// [isLocal] = true  → localhost'a bağlanır (geliştirme)
/// [isLocal] = false → uzak sunucuya bağlanır (canlı)
class AppConfig {
  static const bool isLocal = false;

  static const String _localHost = 'http://127.0.0.1:8080';
  static const String _remoteHost = 'http://94.130.231.165:8080';

  static String get baseHost => isLocal ? _localHost : _remoteHost;
  static String get apiSendUrl => '$baseHost/api/send';
  static String get apiMediaUrl => '$baseHost/api/media';
  static String get apiAuthUrl => '$baseHost/api/auth';

  /// JWT token içeren Authorization header'ları oluşturur.
  static Map<String, String> authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
