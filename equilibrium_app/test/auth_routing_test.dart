import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equilibrium_app/services/auth_repository.dart';
import 'package:equilibrium_app/core/api/api_client.dart';
import 'dart:convert';

void main() {
  group('AuthRepository isLoggedIn', () {
    late ApiClient api;
    late AuthRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = ApiClient(baseUrl: 'http://localhost');
      repo = AuthRepository(api);
    });

    test('cold start with no token -> false (Login)', () async {
      expect(await repo.isLoggedIn(), false);
    });

    test('cold start with valid token -> true (AppShell)', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Create a valid mock JWT
      final exp = (DateTime.now().millisecondsSinceEpoch / 1000).round() + 3600; // 1 hr future
      final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp})));
      final token = 'header.$payload.signature';
      
      await prefs.setString('jwt_token', token);

      expect(await repo.isLoggedIn(), true);
    });

    test('expired token -> false and deleted', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Create an expired mock JWT
      final exp = (DateTime.now().millisecondsSinceEpoch / 1000).round() - 3600; // 1 hr past
      final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp})));
      final token = 'header.$payload.signature';
      
      await prefs.setString('jwt_token', token);

      expect(await repo.isLoggedIn(), false);
      expect(prefs.containsKey('jwt_token'), false);
    });

    test('malformed token -> false and deleted', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', 'invalid_token_format');

      expect(await repo.isLoggedIn(), false);
      expect(prefs.containsKey('jwt_token'), false);
    });
  });
}
