import 'package:flutter/material.dart';

/// Centralized configuration of application colors.
///
/// This class defines all the colors used in the application to ensure consistency
/// and ease of maintenance.
///
/// Usage:
/// Use `AppColors.primaryBlue` for the main brand color.
/// Prefer using `Theme.of(context).colorScheme.primary` in widgets when possible.
class AppColors {
  // Use ValueNotifier to notify listeners when colors change
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  // --- Brand Colors ---

  /// Dark blue based on the company logo.
  /// Used for AppBars, primary buttons, and headings.
  static Color primaryBlue = const Color(0xFF09325E);

  /// Darker variant of primary blue.
  /// Used for gradients or active states.
  static Color primaryDark = const Color(0xFF0D47A1);

  /// Light blue/orange accent from the logo.
  /// Used for secondary actions, highlights, and floating buttons.
  static Color accentOrange = const Color.fromARGB(255, 36, 102, 202);

  /// Light gray for background.
  /// Used as the main scaffold background color.
  static Color backgroundGray = const Color.fromARGB(255, 236, 237, 238);

  // --- UI Colors ---

  /// Pure white.
  static Color white = const Color(0xFFFFFFFF);

  /// Pure black.
  static Color black = const Color(0xFF000000);

  /// Error red.
  /// Used for error states, destructive actions, and validation messages.
  static Color error = const Color(0xFFD32F2F);

  /// Success green.
  /// Used for success messages and completed states.
  static Color success = const Color(
    0xFF2E7D32,
  ); // Adjusted for better visibility

  /// Warning orange/yellow.
  /// Used for warnings and pending states.
  static Color warning = const Color(0xFFED6C02);

  // --- Text Colors ---

  /// Primary text color (dark gray/black).
  /// Used for main content and headings.
  static Color textPrimary = const Color(0xFF212121);

  /// Secondary text color (medium gray).
  /// Used for subtitles and secondary information.
  static Color textSecondary = const Color(0xFF757575);

  // --- Divider/Border Colors ---

  /// Light gray for dividers and borders.
  static Color divider = const Color(0xFFBDBDBD);

  // --- Role Specific Colors (Admin Panel) ---

  static Color roleAdmin = Colors.purple;
  static Color roleSeller = Colors.blue;
  static Color roleTechnician = Colors.blueGrey;
  static Color roleClient = Colors.green;

  // --- Social / External Service Colors ---
  static const Color whatsapp = Color(0xFF25D366);

  /// Actualiza los colores desde un mapa y notifica a los listeners.
  static void updateColors(Map<String, int> colors) {
    if (colors.containsKey('primaryBlue'))
      primaryBlue = Color(colors['primaryBlue']!);
    if (colors.containsKey('primaryDark'))
      primaryDark = Color(colors['primaryDark']!);
    if (colors.containsKey('accentOrange'))
      accentOrange = Color(colors['accentOrange']!);
    if (colors.containsKey('backgroundGray'))
      backgroundGray = Color(colors['backgroundGray']!);

    if (colors.containsKey('white')) white = Color(colors['white']!);
    if (colors.containsKey('black')) black = Color(colors['black']!);
    if (colors.containsKey('error')) error = Color(colors['error']!);
    if (colors.containsKey('success')) success = Color(colors['success']!);
    if (colors.containsKey('warning')) warning = Color(colors['warning']!);

    if (colors.containsKey('textPrimary'))
      textPrimary = Color(colors['textPrimary']!);
    if (colors.containsKey('textSecondary'))
      textSecondary = Color(colors['textSecondary']!);

    if (colors.containsKey('divider')) divider = Color(colors['divider']!);

    if (colors.containsKey('roleAdmin'))
      roleAdmin = Color(colors['roleAdmin']!);
    if (colors.containsKey('roleSeller'))
      roleSeller = Color(colors['roleSeller']!);
    if (colors.containsKey('roleTechnician'))
      roleTechnician = Color(colors['roleTechnician']!);
    if (colors.containsKey('roleClient'))
      roleClient = Color(colors['roleClient']!);

    // Notificar cambios incrementando el valor
    notifier.value++;
  }

  /// Convierte los colores actuales a un mapa para guardarlos.
  static Map<String, int> toColorMap() {
    return {
      'primaryBlue': primaryBlue.value,
      'primaryDark': primaryDark.value,
      'accentOrange': accentOrange.value,
      'backgroundGray': backgroundGray.value,
      'white': white.value,
      'black': black.value,
      'error': error.value,
      'success': success.value,
      'warning': warning.value,
      'textPrimary': textPrimary.value,
      'textSecondary': textSecondary.value,
      'divider': divider.value,
      'roleAdmin': roleAdmin.value,
      'roleSeller': roleSeller.value,
      'roleTechnician': roleTechnician.value,
      'roleClient': roleClient.value,
    };
  }

  /// Restablece los colores a sus valores por defecto
  static void resetToDefaults() {
    primaryBlue = const Color(0xFF09325E);
    primaryDark = const Color(0xFF0D47A1);
    accentOrange = const Color.fromARGB(255, 36, 102, 202);
    backgroundGray = const Color.fromARGB(255, 236, 237, 238);
    white = const Color(0xFFFFFFFF);
    black = const Color(0xFF000000);
    error = const Color(0xFFD32F2F);
    success = const Color(0xFF2E7D32);
    warning = const Color(0xFFED6C02);
    textPrimary = const Color(0xFF212121);
    textSecondary = const Color(0xFF757575);
    divider = const Color(0xFFBDBDBD);
    roleAdmin = Colors.purple;
    roleSeller = Colors.blue;
    roleTechnician = Colors.blueGrey;
    roleClient = Colors.green;

    notifier.value++;
  }
}
