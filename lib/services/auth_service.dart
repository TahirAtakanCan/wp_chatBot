import 'dart:convert';
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
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseHost}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final auth = AuthModel.fromJson(data);
        await _saveAuth(auth);
        return auth;
      }
    } catch (_) {}
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
        'sessionId': auth.sessionId,
        'username': auth.username,
      }),
    );
  }
}
