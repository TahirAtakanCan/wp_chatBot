import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

/// Tüm HTTP isteklerini saran yardımcı fonksiyon.
/// Eğer response 401 ise logout ve login ekranına yönlendirir.
Future<http.Response> httpRequestWrap({
  required BuildContext context,
  required Future<http.Response> Function() request,
  required AuthProvider authProvider,
}) async {
  final response = await request();

  if (response.statusCode == 401 ||
      response.body.contains('token') &&
      (response.body.contains('expired') || response.body.contains('invalid'))) {
    // Token'ı sil ve logout
    await AuthService.logout();
    await authProvider.logout();

    // Login ekranına yönlendir
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  return response;
}
