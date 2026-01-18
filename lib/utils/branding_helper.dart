class BrandingHelper {
  static String _appName = 'TechService Pro';

  static String get appName => _appName;

  static void setAppName(String name) {
    if (name.isNotEmpty) {
      _appName = name;
    }
  }
}
