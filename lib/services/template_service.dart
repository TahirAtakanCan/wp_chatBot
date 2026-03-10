import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/template_model.dart';

class TemplateService {
  String get _baseUrl => AppConfig.baseHost;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return AppConfig.authHeaders(token);
  }

  Future<List<TemplateModel>> getTemplates() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/templates'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List<dynamic>) {
          return decoded
              .map((item) =>
                  TemplateModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }

        if (decoded is Map<String, dynamic>) {
          final list = decoded['templates'];
          if (list is List<dynamic>) {
            return list
                .map((item) =>
                    TemplateModel.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
      }
    } catch (_) {}

    return [];
  }

  Future<bool> createTemplate(String title, String content) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/templates'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'title': title,
              'content': content,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTemplate(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/templates/$id'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTemplate(int id, String title, String content) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/templates/$id'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'title': title,
              'content': content,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
