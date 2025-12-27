// lib/services/preferences_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar preferencias del usuario usando SharedPreferences
class PreferencesService {
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';

  /// Guardar preferencia de "Recordarme"
  Future<void> saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  /// Obtener preferencia de "Recordarme"
  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  /// Guardar email del usuario
  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
  }

  /// Obtener email guardado
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  /// Limpiar email guardado
  Future<void> clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_rememberMeKey);
  }

  /// Guardar ruta de imagen de perfil local
  Future<void> saveProfileImagePath(String uid, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_$uid', path);
  }

  /// Obtener ruta de imagen de perfil local
  Future<String?> getProfileImagePath(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image_$uid');
  }
}
