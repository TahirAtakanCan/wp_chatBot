import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/delivery_record.dart';
import 'auth_service.dart';

class DeliveryService {
  String get _baseUrl => AppConfig.baseHost;

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    final effectiveToken = token ?? '';
    if (effectiveToken.isEmpty) {
      throw Exception('Yetkilendirme tokeni bulunamadi');
    }
    return AppConfig.authHeaders(effectiveToken);
  }

  Future<List<DeliveryRecord>> list({
    int page = 0,
    int size = 50,
    DeliveryStatus? status,
    String sortBy = 'sentAt',
    String direction = 'desc',
  }) async {
    final params = {
      'page': '$page',
      'size': '$size',
      'sortBy': sortBy,
      'direction': direction,
      if (status != null) 'status': status.name,
    };
    final url = Uri.parse('$_baseUrl/api/delivery').replace(
      queryParameters: params,
    );

    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['content'] as List<dynamic>;
      return content
          .map((item) => DeliveryRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception(
      'Gonderim listesi alinamadi: ${response.statusCode}',
    );
  }

  Future<List<DeliveryRecord>> listFailed({int page = 0, int size = 50}) async {
    return list(page: page, size: size, status: DeliveryStatus.failed);
  }

  Future<Map<String, DeliveryStatus>> lookupByPhones(
    List<String> phones,
  ) async {
    final url = Uri.parse('$_baseUrl/api/delivery/lookup');
    final response = await http.post(
      url,
      headers: {
        ...await _authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(phones),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body.map((key, value) {
        final status = DeliveryStatus.values.firstWhere(
          (e) => e.name.toUpperCase() == value.toString().toUpperCase(),
          orElse: () => DeliveryStatus.sent,
        );
        return MapEntry(key, status);
      });
    }

    return {};
  }

  Future<List<DeliveryRecord>> getByPhone(String phone) async {
    final url = Uri.parse('$_baseUrl/api/delivery/by-phone/$phone');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as List<dynamic>;
      return body
          .map((item) => DeliveryRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<Map<String, int>> getStats() async {
    final url = Uri.parse('$_baseUrl/api/delivery/stats');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body.map((key, value) => MapEntry(key, value as int));
    }

    return {};
  }
}
