import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final result = await _authService.login(email, password);

    _isLoading = false;
    
    if (result['success']) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }
  //logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.clearTokens();

    _errorMessage = '';
    _isLoading = false;
    notifyListeners();
  }
}