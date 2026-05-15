import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'api_exceptions.dart';
import 'auth_service.dart';

class ConversationService {
  String get _baseUrl => AppConfig.baseHost;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    final effectiveToken = token ?? '';
    if (effectiveToken.isEmpty) {
      throw ApiException('Yetkilendirme tokeni bulunamadi', statusCode: 401);
    }
    return AppConfig.authHeaders(effectiveToken);
  }

  Future<List<Conversation>> fetchConversations({
    int page = 0,
    int size = 50,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/conversations?page=$page&size=$size'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Konusmalar alinamadi',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    final content = _extractContentList(decoded);
    return content
        .map((item) => Conversation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Message>> fetchMessages(
    int conversationId, {
    int page = 0,
    int size = 100,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/conversations/$conversationId/messages?page=$page&size=$size',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException('Mesajlar alinamadi', statusCode: response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    final content = _extractContentList(decoded);
    return content
        .map((item) => Message.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendReplyImage(
    int conversationId, {
    required String imageUrl,
    String? caption,
  }) async {
    final body = <String, dynamic>{
      'imageUrl': imageUrl,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/reply-image'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Message.fromJson(decoded);
    }

    final errorBody = _decodeAsMap(response.body);
    final errorCode = _extractErrorCode(errorBody);

    if (response.statusCode == 422 && errorCode == 'REPLY_WINDOW_CLOSED') {
      throw ReplyWindowClosedException(
        'Yanit penceresi kapali',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 429) {
      throw RateLimitedException(
        'Cok fazla istek gonderildi',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      errorBody['message']?.toString() ?? 'Resim gonderilemedi',
      statusCode: response.statusCode,
    );
  }

  Future<Message> sendReply(int conversationId, String text) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/reply'),
      headers: await _getHeaders(),
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Message.fromJson(decoded);
    }

    final body = _decodeAsMap(response.body);
    final errorCode = _extractErrorCode(body);

    if (response.statusCode == 422 && errorCode == 'REPLY_WINDOW_CLOSED') {
      throw ReplyWindowClosedException(
        'Yanit penceresi kapali',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 429) {
      throw RateLimitedException(
        'Cok fazla istek gonderildi',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      body['message']?.toString() ?? 'Mesaj gonderilemedi',
      statusCode: response.statusCode,
    );
  }

  Future<Message> sendContactCard(int conversationId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/send-contact-card'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Message.fromJson(decoded);
    }

    if (response.statusCode == 422) {
      throw ReplyWindowClosedException(
        'Yanit penceresi kapali',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 429) {
      throw RateLimitedException(
        'Cok fazla istek gonderildi',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Kişi kartı gönderilemedi',
      statusCode: response.statusCode,
    );
  }

  Future<Conversation> closeConversation(int conversationId) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/close'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Konusma kapatilamadi',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Conversation.fromJson(decoded);
  }

  /// Bir conversation'ın TÜM mesajlarını sil (conversation'ı temizle)
  /// Dönüş: {"deleted": silinen_mesaj_sayisi}
  Future<int> clearAllMessages(int conversationId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/messages'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return _toInt(decoded['deleted']);
    }

    if (response.statusCode == 404) {
      throw ApiException(
        'Konusma bulunamadi',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Mesajlar silinirken hata',
      statusCode: response.statusCode,
    );
  }

  /// Tek bir mesajı sil
  /// Dönüş: 204 No Content (boş döner)
  Future<void> deleteMessage(int conversationId, int messageId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/conversations/$conversationId/messages/$messageId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 204) {
      return; // Başarılı
    }

    if (response.statusCode == 404) {
      throw ApiException(
        'Mesaj bulunamadi',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Mesaj silinirken hata',
      statusCode: response.statusCode,
    );
  }

  /// Conversation'ı tüm mesajlarıyla birlikte sil
  /// Dönüş: {"deletedConversationId": id, "deletedMessages": sayi}
  Future<Map<String, dynamic>> deleteConversation(int conversationId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/conversations/$conversationId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded;
    }

    if (response.statusCode == 404) {
      throw ApiException(
        'Konusma bulunamadi',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Konusma silinirken hata',
      statusCode: response.statusCode,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<dynamic> _extractContentList(dynamic decoded) {
    if (decoded is List<dynamic>) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final content = decoded['content'];
      if (content is List<dynamic>) {
        return content;
      }
    }

    return const [];
  }

  Map<String, dynamic> _decodeAsMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _extractErrorCode(Map<String, dynamic> body) {
    final raw = body['code'] ?? body['status'] ?? body['error'];
    return (raw ?? '').toString().trim().toUpperCase();
  }
}