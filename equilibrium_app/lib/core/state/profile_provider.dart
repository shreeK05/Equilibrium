import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../../models/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _api;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  ThemeMode _themeMode = ThemeMode.system;

  ProfileProvider(this._api) {
    _loadThemeFromPrefs();
  }

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_preference') ?? 'system';
    _themeMode = _themeModeFromString(saved);
    notifyListeners();
  }

  ThemeMode _themeModeFromString(String val) {
    switch (val) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final json = await _api.get('/profile');
      _profile = UserProfile.fromJson(json as Map<String, dynamic>);
      // Sync theme mode from server preference
      _themeMode = _themeModeFromString(_profile!.themePreference);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', _profile!.themePreference);
    } catch (e) {
      _errorMessage = 'Could not load profile.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    _isLoading = true;
    notifyListeners();
    try {
      final json = await _api.patch('/profile', body: updates);
      _profile = UserProfile.fromJson(json as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not save profile. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTheme(String preference) async {
    _themeMode = _themeModeFromString(preference);
    notifyListeners();
    // Persist locally immediately for instant effect
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preference', preference);
    // Persist to server
    try {
      await _api.patch('/profile', body: {'themePreference': preference});
      if (_profile != null) {
        _profile = _profile!.copyWith(themePreference: preference);
      }
    } catch (_) {
      // Local change is still applied; server sync is best-effort
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
