import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_error_mapper.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo;
  
  AuthStatus _status = AuthStatus.initial;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFirstRun = false;

  AuthProvider(this._authRepo) {
    _checkStatus();
  }

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isFirstRun => _isFirstRun;

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasToken = await _authRepo.isLoggedIn();
    _isFirstRun = prefs.getBool('is_first_run') ?? true;

    if (hasToken) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false);
    _isFirstRun = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepo.login(email, password);
      _status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      _errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
    } catch (e) {
      _errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepo.register(email, password);
      _status = AuthStatus.authenticated;
      // Also implies first run for a new user
      _isFirstRun = true;
    } on ApiException catch (e) {
      _errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
    } catch (e) {
      _errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void forceLogout() {
    // Used when ApiClient intercepts a 401
    logout();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
