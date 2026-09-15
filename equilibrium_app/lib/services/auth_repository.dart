import '../../core/api/api_client.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<void> login(String email, String password) async {
    final response = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    final token = response['token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> register(String email, String password) async {
    final response = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
    });

    final token = response['token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        await logout();
        return false;
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      );
      final exp = payload['exp'] as int?;
      if (exp == null) return true; // fallback if no exp

      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      if (now >= exp) {
        await logout();
        return false;
      }
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }
}
