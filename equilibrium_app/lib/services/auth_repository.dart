import '../../core/api/api_client.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<void> login(String email, String password) async {
    final response = await _api.post('/auth/login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    final token = response['token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Request 6-digit verification code to initiate registration
  Future<Map<String, dynamic>> registerRequest(
    String email,
    String password, {
    String? name,
    String? timezone,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
    };
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    if (timezone != null) {
      body['timezone'] = timezone;
    }

    final response = await _api.post('/auth/register-request', body: body);
    return response as Map<String, dynamic>;
  }

  /// Verify 6-digit code and store authenticated session JWT
  Future<void> verifyOtp(String email, String otp) async {
    final response = await _api.post('/auth/verify-registration-otp', body: {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });

    final token = response['token'];
    if (token == null) {
      throw ApiException(500, 'INTERNAL_ERROR', 'No authentication token received');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Resend a fresh 6-digit code
  Future<Map<String, dynamic>> resendOtp(String email) async {
    final response = await _api.post('/auth/resend-registration-otp', body: {
      'email': email.trim().toLowerCase(),
    });
    return response as Map<String, dynamic>;
  }

  /// Legacy register method preserved for backward compatibility
  Future<void> register(String email, String password) async {
    final response = await _api.post('/auth/register', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    final token = response?['token'];
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
    }
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
