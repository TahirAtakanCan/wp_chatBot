import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/auth_model.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  /// Login isteği gönderir, başarılıysa AuthModel döner.
  static Future<AuthModel?> login(String username, String password) async {
    try {
      final uri = Uri.parse('${AppConfig.apiAuthUrl}/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          debugPrint('[AuthService] Beklenmeyen login response: ${response.body}');
          return null;
        }

        final data = Map<String, dynamic>.from(decoded);
        // Bazı backend cevaplarında username/role gelmeyebilir.
        data.putIfAbsent('username', () => username.trim());

        final auth = AuthModel.fromJson(data);
        if (auth.token.isEmpty) {
          debugPrint('[AuthService] Login 200 ama token boş.');
          return null;
        }
        await _saveAuth(auth);
        return auth;
      }
      debugPrint(
        '[AuthService] Login başarısız (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      debugPrint('[AuthService] Login exception: $e');
    }
    return null;
  }

  /// Kayıtlı token ve kullanıcı bilgisini döndürür.
  static Future<AuthModel?> getSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    try {
      return AuthModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Token'ı döndürür.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Oturum bilgisini temizler.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Oturum açık mı?
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> _saveAuth(AuthModel auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, auth.token);
    await prefs.setString(
      _userKey,
      jsonEncode({
        'token': auth.token,
        'role': auth.role,
        'username': auth.username,
        'sessionId': auth.sessionId,
      }),
    );
  }
}
