import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/meta_template.dart';
import '../models/template_model.dart';
import '../models/template_preset.dart';

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

  Future<List<MetaTemplate>> fetchMetaTemplates() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/templates/meta'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Meta template listesi alınamadı: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> list;
    if (decoded is List<dynamic>) {
      list = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['templates'] is List) {
      list = decoded['templates'] as List<dynamic>;
    } else {
      list = const [];
    }
    return list
        .map((item) => MetaTemplate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MetaTemplate>> refreshMetaTemplates() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/templates/meta/refresh'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Yenileme başarısız: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> templates;
    if (decoded is Map<String, dynamic> && decoded['templates'] is List) {
      templates = decoded['templates'] as List<dynamic>;
    } else if (decoded is List<dynamic>) {
      templates = decoded;
    } else {
      templates = const [];
    }
    return templates
        .map((item) => MetaTemplate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TemplatePreset>> fetchPresets() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/templates/presets'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> list;
    if (decoded is List<dynamic>) {
      list = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['presets'] is List) {
      list = decoded['presets'] as List<dynamic>;
    } else {
      list = const [];
    }

    return list
        .map((item) => TemplatePreset.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TemplatePreset> createPreset({
    required String displayName,
    required String metaTemplateName,
    String language = 'tr',
    String? mediaType,
    String? mediaUrl,
    String? mediaFilename,
    int? mediaSizeBytes,
    String? mimeType,
  }) async {
    final body = {
      'displayName': displayName,
      'metaTemplateName': metaTemplateName,
      'language': language,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaFilename != null) 'mediaFilename': mediaFilename,
      if (mediaSizeBytes != null) 'mediaSizeBytes': mediaSizeBytes,
      if (mimeType != null) 'mimeType': mimeType,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/api/templates/presets'),
      headers: {
        ...(await _getHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode(body)),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = _decodeError(response.bodyBytes);
      throw Exception(error ?? 'Hazır kayıt oluşturulamadı');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return TemplatePreset.fromJson(data as Map<String, dynamic>);
  }

  Future<TemplatePreset> updatePreset(
    int id, {
    required String displayName,
    String? mediaType,
    String? mediaUrl,
    String? mediaFilename,
    int? mediaSizeBytes,
    String? mimeType,
    String? metaTemplateName,
    String language = 'tr',
  }) async {
    final body = {
      'displayName': displayName,
      'language': language,
      if (metaTemplateName != null) 'metaTemplateName': metaTemplateName,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'mediaFilename': mediaFilename,
      'mediaSizeBytes': mediaSizeBytes,
      'mimeType': mimeType,
    };

    final response = await http.put(
      Uri.parse('$_baseUrl/api/templates/presets/$id'),
      headers: {
        ...(await _getHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode(body)),
    );

    if (response.statusCode != 200) {
      final error = _decodeError(response.bodyBytes);
      throw Exception(error ?? 'Hazır kayıt güncellenemedi');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return TemplatePreset.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePreset(int id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/templates/presets/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Silme başarısız');
    }
  }

  String? _decodeError(List<int> bodyBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString();
      }
    } catch (_) {}
    return null;
  }
}
