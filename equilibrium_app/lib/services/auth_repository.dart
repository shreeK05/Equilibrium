import '../../core/api/api_client.dart';
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
    return prefs.containsKey('jwt_token');
  }
}
