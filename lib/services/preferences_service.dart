// lib/services/preferences_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar preferencias del usuario usando SharedPreferences
/// Service to manage local user preferences using the [shared_preferences] package.
/// Used for "Remember Me" logic, caching email, and local profile image paths.
class PreferencesService {
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';

  /// Persists the "Remember Me" flag.
  Future<void> saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  /// Retrieves the "Remember Me" flag.
  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  /// Caches the user's email locally.
  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
  }

  /// Retrieves the cached email.
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  /// Clears specific cached credentials.
  Future<void> clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_rememberMeKey);
  }

  /// Saves a local file path for the user's profile image.
  Future<void> saveProfileImagePath(String uid, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_$uid', path);
  }

  /// Retrieves a specific user's local profile image path.
  Future<String?> getProfileImagePath(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image_$uid');
  }
}
