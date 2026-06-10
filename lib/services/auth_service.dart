import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2/api';
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Accept': 'application/json'},
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await storage.write(key: 'auth_token', value: data['access_token']);
        await storage.write(key: 'user_role', value: data['user']['role']);

        return {'success': true, 'role': data['user']['role']};
      } else {
        return {'success': false, 'message': 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Check server.'};
    }
  }

  Future<void> clearTokens() async {
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'user_role');
  }
}