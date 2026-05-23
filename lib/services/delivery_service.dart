import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/delivery_record.dart';
import '../models/export_options.dart';
import '../models/failure_category.dart';
import 'auth_service.dart';
import 'web_file_download_stub.dart'
    if (dart.library.html) 'web_file_download_web.dart' as web_download;

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
      if (status != null) 'status': status.name.toUpperCase(),
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

  /// 2 günden eski gönderim kayıtlarını siler. Sunucu desteklemiyorsa 0 döner.
  Future<int> purgeOlderThan({int days = 2}) async {
    final candidates = [
      Uri.parse('$_baseUrl/api/delivery/purge').replace(
        queryParameters: {'days': '$days'},
      ),
      Uri.parse('$_baseUrl/api/delivery/cleanup').replace(
        queryParameters: {'days': '$days'},
      ),
      Uri.parse('$_baseUrl/api/delivery/old').replace(
        queryParameters: {'olderThanDays': '$days'},
      ),
    ];

    for (final url in candidates) {
      try {
        final response = await http.delete(url, headers: await _authHeaders());
        if (response.statusCode == 200 || response.statusCode == 204) {
          if (response.body.isEmpty) return 0;
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            return (body['deleted'] ?? body['deletedCount'] ?? 0) as int;
          }
          if (body is int) return body;
          return 0;
        }
      } catch (_) {
        continue;
      }
    }

    return 0;
  }

  Future<void> downloadExcel({DeliveryStatus? status, int? days}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status.name.toUpperCase();
    if (days != null) params['days'] = '$days';

    final url = Uri.parse('$_baseUrl/api/delivery/export').replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode != 200) {
      throw Exception('Excel indirme başarısız: ${response.statusCode}');
    }

    if (!kIsWeb) {
      throw UnsupportedError(
        'Excel indirme şu an sadece web tarayıcıda destekleniyor',
      );
    }

    web_download.downloadBytes(
      bytes: response.bodyBytes,
      filename: _suggestFilenameLegacy(status, days),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<List<FailureCategory>> fetchFailureCategories() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/delivery/failure-categories'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Kategori listesi alınamadı');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List<dynamic>) return [];
    return decoded
        .map((item) => FailureCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> downloadExcelWithOptions(ExportOptions options) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/delivery/export'),
      headers: {
        ...(await _authHeaders()),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonEncode(options.toJson())),
    );

    if (response.statusCode != 200) {
      throw Exception('Excel indirme başarısız: ${response.statusCode}');
    }

    if (!kIsWeb) {
      throw UnsupportedError(
        'Excel indirme şu an sadece web tarayıcıda destekleniyor',
      );
    }

    web_download.downloadBytes(
      bytes: response.bodyBytes,
      filename: _suggestFilename(options),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  String _suggestFilenameLegacy(DeliveryStatus? status, int? days) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    var suffix = '';
    if (status != null) suffix += '_${status.name.toLowerCase()}';
    if (days != null) suffix += '_son${days}gun';
    return 'gonderim_raporu${suffix}_$dateStr.xlsx';
  }

  String _suggestFilename(ExportOptions options) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    var suffix = '';
    if ((options.status ?? '').isNotEmpty) {
      suffix += '_${options.status!.toLowerCase()}';
    }
    if (options.days != null) suffix += '_son${options.days}gun';

    return 'gonderim_raporu${suffix}_$dateStr.xlsx';
  }
}
