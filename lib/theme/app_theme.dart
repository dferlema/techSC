// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Colores de la aplicación TechService Pro
/// Basados en el logo de la empresa
class AppColors {
  // Colores principales del logo
  static const Color primaryBlue = Color(
    0xFF09325E,
  ); // Azul oscuro basado en la imagen
  static const Color accentOrange = Color.fromARGB(
    255,
    36,
    102,
    202,
  ); // Azul claro
  static const Color backgroundGray = Color.fromARGB(
    255,
    236,
    237,
    238,
  ); // Gris muy claro

  // Colores adicionales
  static const Color white = Color.fromARGB(255, 236, 237, 238);
  static const Color black = Color.fromARGB(255, 0, 0, 0);
  static const Color error = Color.fromARGB(255, 211, 47, 47);
  static const Color success = Color.fromARGB(255, 41, 107, 45);
  static const Color warning = Color.fromARGB(255, 63, 179, 108);

  // Variaciones para modo oscuro - Colores vibrantes y modernos
  static const Color primaryBlueDark = Color(0xFF3B82F6); // Electric blue
  static const Color accentOrangeDark = Color(0xFF06B6D4); // Bright cyan
  static const Color backgroundDark = Color(0xFF0A1929); // Deep dark blue-gray
  static const Color surfaceDark = Color(0xFF1A2332); // Elevated dark surface
  static const Color surfaceVariantDark = Color(0xFF243447); // Lighter surface

  // Grises para texto y bordes
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);
}

/// Extensión para acceder fácilmente a colores personalizados desde el tema
extension AppColorScheme on ColorScheme {
  /// Color naranja de acento del logo
  Color get accentOrange => AppColors.accentOrange;

  /// Color de fondo gris claro
  Color get backgroundGray => AppColors.backgroundGray;
}

/// Tema centralizado de la aplicación
class AppTheme {
  /// Helper para construir el TextTheme consistente
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: primaryColor,
        inherit: true,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryColor,
        inherit: true,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: primaryColor,
        inherit: true,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        inherit: true,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        inherit: true,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primaryColor,
        inherit: true,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primaryColor,
        inherit: true,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: primaryColor,
        inherit: true,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
        inherit: true,
      ),
    );
  }

  /// Tema claro (Light Mode)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme basado en los colores del logo
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentOrange,
        surface: AppColors.white,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.textPrimary,
        onError: AppColors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundGray,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Botones outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppColors.white,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundGray,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundGray,
        selectedColor: AppColors.primaryBlue,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),

      // IconTheme
      iconTheme: const IconThemeData(color: AppColors.primaryBlue, size: 24),

      // Text Theme
      // Text Theme Centralizado
      textTheme: _buildTextTheme(
        AppColors.textPrimary,
        AppColors.textSecondary,
      ),
    );
  }

  /// Tema oscuro (Dark Mode) - Vibrante y moderno
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme para modo oscuro con colores vibrantes
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryBlueDark,
        secondary: AppColors.accentOrangeDark,
        surface: AppColors.surfaceDark,
        surfaceContainerHighest: AppColors.surfaceVariantDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
        outline: const Color(0xFF475569),
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // AppBar con gradiente sutil
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlueDark,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlueDark,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),

      // Cards con elevación mejorada
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.surfaceDark,
        shadowColor: Colors.black.withOpacity(0.3),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryBlueDark,
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryBlueDark,
            width: 2,
          ),
        ),
      ),

      // Text Theme Centralizado (Para consistencia)
      textTheme: _buildTextTheme(Colors.white, const Color(0xFF94A3B8)),

      // Icon Theme
      iconTheme: IconThemeData(color: AppColors.primaryBlueDark, size: 24),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
    );
  }
}
