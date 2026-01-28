// lib/services/preferences_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado para gestionar preferencias del usuario usando SharedPreferences.
/// Centralized service to manage local user preferences.
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _sessionStartKey = 'session_start_time';

  // --- Auth & Profile ---

  Future<void> saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  Future<void> clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_rememberMeKey);
  }

  Future<void> saveProfileImagePath(String uid, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_$uid', path);
  }

  Future<String?> getProfileImagePath(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image_$uid');
  }

  // --- Onboarding ---

  Future<bool> getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, value);
  }

  // --- Session Management ---

  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionStartKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_sessionStartKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStartKey);
  }

  Future<bool> isSessionExpired() async {
    final last = await getLastActivity();
    if (last == null) return true;
    final diff = DateTime.now().difference(last);
    // Sesión expira tras 10 minutos de inactividad
    return diff.inMinutes >= 10;
  }
}
