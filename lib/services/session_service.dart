import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Yeni session oluşturur
  Future<bool> createSession(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      debugPrint('SESSION CREATE - Token: $token');
      debugPrint('SESSION CREATE - SessionId: $sessionId');

      final url = Uri.parse('$_baseUrl/api/session/create');
      debugPrint('SESSION CREATE - URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sessionId': sessionId}),
      );

      debugPrint('SESSION CREATE - Status: ${response.statusCode}');
      debugPrint('SESSION CREATE - Body: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('SESSION CREATE - HATA: $e');
      return false;
    }
  }

  /// Belirtilen session'ı siler
  Future<bool> deleteSession(String sessionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/session/${Uri.encodeComponent(sessionId)}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Session durumunu döndürür (qr, connected, user)
  Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/session/${Uri.encodeComponent(sessionId)}/status'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }
}
