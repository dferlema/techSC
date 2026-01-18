import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _sessionStartKey = 'session_start_time';

  Future<bool> getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, value);
  }

  // 🕒 Gestión de Sesión basado en Actividad
  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionStartKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Mantener alias por compatibilidad inicial
  Future<void> setSessionStart(DateTime time) async => updateLastActivity();

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
    return diff.inMinutes >= 10;
  }
}
