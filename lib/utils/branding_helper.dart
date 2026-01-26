import '../models/config_model.dart';

class BrandingHelper {
  static String _appName = 'TechService Pro';
  static String _companyEmail = 'techservicecomputer@hotmail.com';
  static String _companyPhone = '0991090805';
  static String _companyAddress = 'De los Guabos n47-313, Quito';

  static String get appName => _appName;
  static String get companyEmail => _companyEmail;
  static String get companyPhone => _companyPhone;
  static String get companyAddress => _companyAddress;

  static void setAppName(String name) {
    if (name.isNotEmpty) {
      _appName = name;
    }
  }

  static void setConfig(ConfigModel config) {
    if (config.companyName.isNotEmpty) _appName = config.companyName;
    if (config.companyEmail.isNotEmpty) _companyEmail = config.companyEmail;
    if (config.companyPhone.isNotEmpty) _companyPhone = config.companyPhone;
    if (config.companyAddress.isNotEmpty)
      _companyAddress = config.companyAddress;
  }
}
