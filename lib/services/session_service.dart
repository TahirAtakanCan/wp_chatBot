import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/session_model.dart';

class SessionService {
  static String get _baseUrl => AppConfig.baseHost;

  /// Tüm aktif session listesini döndürür
  static Future<List<SessionModel>> getAllSessions() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/sessions'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sessions = data['sessions'] as List<dynamic>? ?? [];
        return sessions
            .map((s) => SessionModel.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Yeni session oluşturur
  static Future<bool> createSession(String sessionId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/session/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sessionId': sessionId}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Belirtilen session'ı siler
  static Future<bool> deleteSession(String sessionId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/session/${Uri.encodeComponent(sessionId)}'),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Session durumunu döndürür (qr, connected, user)
  static Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/session/${Uri.encodeComponent(sessionId)}/status'),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }
}
