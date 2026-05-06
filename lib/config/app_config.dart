/// Backend adresi dart-define ile verilir.
/// Ornek:
/// --dart-define=BACKEND_HOST=127.0.0.1
/// --dart-define=BACKEND_PORT=8080
class AppConfig {
  static const String _scheme =
      String.fromEnvironment('BACKEND_SCHEME', defaultValue: 'http');
  static const String _host =
      String.fromEnvironment('BACKEND_HOST', defaultValue: 'localhost');
  static const String _port =
      String.fromEnvironment('BACKEND_PORT', defaultValue: '8080');

  static String get baseHost {
    return _port.isEmpty ? '$_scheme://$_host' : '$_scheme://$_host:$_port';
  }

  static String get apiSendUrl => '$baseHost/api/send';
  static String get apiMediaUrl => '$baseHost/api/media';
  static String get apiAuthUrl => '$baseHost/api/auth';

  /// JWT token içeren Authorization header'ları oluşturur.
  static Map<String, String> authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
