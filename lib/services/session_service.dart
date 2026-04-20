import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/session_model.dart';

class SessionService {
  final String token;

  SessionService({required this.token});

  String get _baseUrl => AppConfig.baseHost;

  /// Token'ı doğrular; boşsa SharedPreferences'tan okur.
  Future<Map<String, String>> _getHeaders() async {
    String effectiveToken = token;
    if (effectiveToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      effectiveToken = prefs.getString('auth_token') ?? '';
    }
    return AppConfig.authHeaders(effectiveToken);
  }

  /// Tüm aktif session listesini döndürür
  Future<List<SessionModel>> getAllSessions() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/sessions'),
            headers: headers,
          )
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

  /// Meta API entegrasyon endpoint'ine erişim durumunu kontrol eder.
  Future<bool> isIntegrationReachable() async {
    final endpoints = [
      '$_baseUrl/api/health',
      '$_baseUrl/api/status',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(Uri.parse(endpoint))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // Sonraki endpoint denenir.
      }
    }

    return false;
  }
}
