import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

/// Chat icin public medya yukleme (reply-image oncesi).
class ChatMediaService {
  Future<String> uploadPublicImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Yetkilendirme tokeni bulunamadi');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiMediaUrl}/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Medya yuklenemedi (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Gecersiz medya yaniti');
    }

    final url = data['url'] ??
        data['mediaUrl'] ??
        data['imageUrl'] ??
        data['publicUrl'];
    if (url == null || url.toString().trim().isEmpty) {
      throw Exception('Medya URL alinamadi');
    }

    final raw = url.toString().trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return '${AppConfig.baseHost}$raw';
    }
    return '${AppConfig.baseHost}/$raw';
  }
}
