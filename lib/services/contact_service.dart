import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/contact_model.dart';
import 'auth_service.dart';
import '../providers/auth_provider.dart';
import '../http_helper.dart';

class ContactService {
  final String _baseUrl = AppConfig.baseHost;

  Future<String?> _getToken() async {
    return await AuthService.getToken();
  }

  Future<List<ContactModel>> getAllContacts(BuildContext context, AuthProvider authProvider) async {
    final token = await _getToken();
    final response = await httpRequestWrap(
      context: context,
      authProvider: authProvider,
      request: () => http.get(
        Uri.parse('$_baseUrl/api/contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => ContactModel.fromJson(e)).toList();
    } else {
      throw Exception('Kişiler alınamadı');
    }
  }

  Future<bool> deleteContact(BuildContext context, AuthProvider authProvider, int id) async {
    final token = await _getToken();
    final response = await httpRequestWrap(
      context: context,
      authProvider: authProvider,
      request: () => http.delete(
        Uri.parse('$_baseUrl/api/contacts/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteAllContacts(BuildContext context, AuthProvider authProvider) async {
    final token = await _getToken();
    final response = await httpRequestWrap(
      context: context,
      authProvider: authProvider,
      request: () => http.delete(
        Uri.parse('$_baseUrl/api/contacts/all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    return response.statusCode == 200;
  }

  Future<List<ContactModel>> searchContacts(BuildContext context, AuthProvider authProvider, String query) async {
    final token = await _getToken();
    final response = await httpRequestWrap(
      context: context,
      authProvider: authProvider,
      request: () => http.get(
        Uri.parse('$_baseUrl/api/contacts/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
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
  Future<Map<String, dynamic>> syncFromGoogleSheets(BuildContext context, AuthProvider authProvider, String sheetUrl) async {
    final token = await _getToken();
    final response = await httpRequestWrap(
      context: context,
      authProvider: authProvider,
      request: () => http.post(
        Uri.parse('$_baseUrl/api/contacts/sync-sheets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'sheetUrl': sheetUrl}),
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Google Sheets senkronizasyonu başarısız');
    }
  }
}