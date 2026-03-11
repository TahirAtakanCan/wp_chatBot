import 'package:flutter/material.dart';
import '../models/auth_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  String? get sessionId => _currentUser?.sessionId;
  String? get token => _currentUser?.token;

  /// Uygulama açılışında kayıtlı oturumu kontrol eder.
  Future<void> tryAutoLogin() async {
    final saved = await AuthService.getSavedAuth();
    if (saved != null) {
      _currentUser = saved;
      notifyListeners();
    }
  }

  /// Kullanıcı girişi yapar.
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final auth = await AuthService.login(username, password);

    if (auth != null) {
      _currentUser = auth;
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Kullanıcı adı veya şifre hatalı.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Oturumu kapatır.
  Future<void> logout() async {
    await AuthService.logout();
    _currentUser = null;
    _errorMessage = null;
    // Kişi rehberi provider'ını da temizle
    // Eğer MessageProvider veya benzeri bir provider kullanıyorsan:
    // MessageProvider().phoneController.clear();
    // MessageProvider()._phoneNumbers = [];
    notifyListeners();
  }
}
