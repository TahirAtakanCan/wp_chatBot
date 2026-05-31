import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auto_reply.dart';
import 'auth_service.dart';

class AutoReplyService {
  String get _baseUrl => AppConfig.baseHost;

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    final effectiveToken = token ?? '';
    if (effectiveToken.isEmpty) {
      throw Exception('Yetkilendirme tokeni bulunamadı');
    }
    return AppConfig.authHeaders(effectiveToken);
  }

  Future<List<AutoReply>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auto-reply/replies'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Liste alınamadı');
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data.map((j) => AutoReply.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<AutoReply> create({
    required String category,
    required String keywords,
    required String replyText,
    bool active = true,
    int priority = 100,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auto-reply/replies'),
      headers: {
        ...(await _authHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode({
        'category': category,
        'keywords': keywords,
        'replyText': replyText,
        'active': active,
        'priority': priority,
      })),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception(err['message'] as String? ?? 'Oluşturma başarısız');
    }
    return AutoReply.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AutoReply> update(
    int id, {
    required String category,
    required String keywords,
    required String replyText,
    bool active = true,
    int priority = 100,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/auto-reply/replies/$id'),
      headers: {
        ...(await _authHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode({
        'category': category,
        'keywords': keywords,
        'replyText': replyText,
        'active': active,
        'priority': priority,
      })),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception(err['message'] as String? ?? 'Güncelleme başarısız');
    }
    return AutoReply.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/auto-reply/replies/$id'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Silme başarısız');
    }
  }

  Future<AutoReply> toggle(int id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auto-reply/replies/$id/toggle'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Durum değiştirme başarısız');
    return AutoReply.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AutoReplySettings> getSettings() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auto-reply/settings'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Ayarlar alınamadı');
    return AutoReplySettings.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AutoReplySettings> updateSettings(AutoReplySettings settings) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/auto-reply/settings'),
      headers: {
        ...(await _authHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode(settings.toJson())),
    );
    if (response.statusCode != 200) throw Exception('Ayarlar kaydedilemedi');
    return AutoReplySettings.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> testMessage(String message) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auto-reply/test'),
      headers: {
        ...(await _authHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode({'message': message})),
    );
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
