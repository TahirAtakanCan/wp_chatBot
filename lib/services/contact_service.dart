import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/contact_model.dart';
import 'auth_service.dart';

class ContactService {
  final String _baseUrl = AppConfig.baseHost;

  Future<String?> _getToken() async {
    return await AuthService.getToken();
  }

  Future<List<ContactModel>> getAllContacts() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/contacts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => ContactModel.fromJson(e)).toList();
    } else {
      throw Exception('Kişiler alınamadı');
    }
  }

  Future<bool> deleteContact(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/contacts/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteAllContacts() async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/contacts/all'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    return response.statusCode == 200;
  }

  Future<List<ContactModel>> searchContacts(String query) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/contacts/search?q=$query'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => ContactModel.fromJson(e)).toList();
    } else {
      throw Exception('Kişi arama başarısız');
    }
  }

  /// Google Sheets URL'sinden rehberi günceller.
  /// Döner: { "imported": int, "skipped": int }
  Future<Map<String, dynamic>> syncFromGoogleSheets(String sheetUrl) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/contacts/sync-sheets'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'sheetUrl': sheetUrl}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Google Sheets senkronizasyonu başarısız');
    }
  }
}