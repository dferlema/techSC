import 'package:flutter/material.dart';

/// Configuración centralizada de colores de la aplicación TechService Pro.
///
/// Esta clase define todos los colores usados en la aplicación para garantizar
/// consistencia y facilidad de mantenimiento.
///
/// Uso:
/// - Preferir `Theme.of(context).colorScheme.primary` en widgets cuando sea posible.
/// - Usar `AppColors.X` directamente solo cuando no haya equivalente en el colorScheme.
class AppColors {
  // ValueNotifier para notificar a los listeners cuando los colores cambien
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  // --- Colores de Marca ---

  /// Azul oscuro basado en el logo de la empresa.
  /// Usado en AppBars, botones primarios y encabezados.
  static Color primaryBlue = const Color(0xFF09325E);

  /// Variante más oscura del azul primario.
  /// Usada para gradientes o estados activos.
  static Color primaryDark = const Color(0xFF0D47A1);

  /// Azul de acento (anteriormente nombrado accentOrange por error).
  /// Usado para acciones secundarias, destacados y botones flotantes.
  static Color accentBlue = const Color(0xFF2466CA);

  /// Gris claro para fondos de scaffolds.
  /// Color principal de fondo de la aplicación.
  static Color backgroundGray = const Color(0xFFECEDEE);

  /// Superficie muy clara, para tarjetas o secciones diferenciadas.
  /// Alternativa más clara que backgroundGray (ej: 0xFFF8F9FA, 0xFFF5F7FA).
  static Color surfaceLight = const Color(0xFFF8F9FA);

  // --- Colores de UI ---

  /// Blanco puro.
  static Color white = const Color(0xFFFFFFFF);

  /// Negro puro.
  static Color black = const Color(0xFF000000);

  /// Negro suave (casi negro).
  /// Usado para texto de alta jerarquía en pantallas de detalle (ej: 0xFF111111).
  static Color nearBlack = const Color(0xFF111111);

  /// Dorado para elementos de navegación activos.
  /// Usado en el BottomNavigationBar como color seleccionado.
  static Color goldAccent = const Color(0xFFE4A319);

  /// Rojo de error.
  /// Usado en estados de error, acciones destructivas y mensajes de validación.
  static Color error = const Color(0xFFD32F2F);

  /// Verde de éxito.
  /// Usado en mensajes de éxito y estados completados.
  static Color success = const Color(0xFF2E7D32);

  /// Naranja de advertencia.
  /// Usado en advertencias y estados pendientes.
  static Color warning = const Color(0xFFED6C02);

  // --- Colores de Texto ---

  /// Color de texto primario (gris oscuro/negro).
  /// Usado para contenido principal y encabezados.
  static Color textPrimary = const Color(0xFF212121);

  /// Color de texto secundario (gris medio).
  /// Usado para subtítulos e información secundaria.
  static Color textSecondary = const Color(0xFF757575);

  // --- Colores de Divisor/Borde ---

  /// Gris claro para divisores y bordes.
  static Color divider = const Color(0xFFBDBDBD);

  // --- Colores por Rol (Panel Admin) ---

  /// Violeta para rol Administrador.
  static Color roleAdmin = const Color(0xFF9C27B0);

  /// Azul para rol Vendedor.
  static Color roleSeller = const Color(0xFF1976D2);

  /// Azul gris para rol Técnico.
  static Color roleTechnician = const Color(0xFF546E7A);

  /// Verde para rol Cliente.
  static Color roleClient = const Color(0xFF388E3C);

  // --- Colores de Servicios Externos ---

  /// Verde WhatsApp.
  static const Color whatsapp = Color(0xFF25D366);

  /// Actualiza los colores desde un mapa y notifica a los listeners.
  static void updateColors(Map<String, int> colors) {
    if (colors.containsKey('primaryBlue')) {
      primaryBlue = Color(colors['primaryBlue']!);
    }
    if (colors.containsKey('primaryDark')) {
      primaryDark = Color(colors['primaryDark']!);
    }
    if (colors.containsKey('accentBlue')) {
      accentBlue = Color(colors['accentBlue']!);
    }
    if (colors.containsKey('backgroundGray')) {
      backgroundGray = Color(colors['backgroundGray']!);
    }
    if (colors.containsKey('surfaceLight')) {
      surfaceLight = Color(colors['surfaceLight']!);
    }

    if (colors.containsKey('white')) white = Color(colors['white']!);
    if (colors.containsKey('black')) black = Color(colors['black']!);
    if (colors.containsKey('nearBlack')) {
      nearBlack = Color(colors['nearBlack']!);
    }
    if (colors.containsKey('goldAccent')) {
      goldAccent = Color(colors['goldAccent']!);
    }
    if (colors.containsKey('error')) error = Color(colors['error']!);
    if (colors.containsKey('success')) success = Color(colors['success']!);
    if (colors.containsKey('warning')) warning = Color(colors['warning']!);

    if (colors.containsKey('textPrimary')) {
      textPrimary = Color(colors['textPrimary']!);
    }
    if (colors.containsKey('textSecondary')) {
      textSecondary = Color(colors['textSecondary']!);
    }

    if (colors.containsKey('divider')) divider = Color(colors['divider']!);

    if (colors.containsKey('roleAdmin')) {
      roleAdmin = Color(colors['roleAdmin']!);
    }
    if (colors.containsKey('roleSeller')) {
      roleSeller = Color(colors['roleSeller']!);
    }
    if (colors.containsKey('roleTechnician')) {
      roleTechnician = Color(colors['roleTechnician']!);
    }
    if (colors.containsKey('roleClient')) {
      roleClient = Color(colors['roleClient']!);
    }

    // Notificar cambios incrementando el valor
    notifier.value++;
  }

  /// Convierte los colores actuales a un mapa para guardarlos.
  static Map<String, int> toColorMap() {
    return {
      'primaryBlue': primaryBlue.value,
      'primaryDark': primaryDark.value,
      'accentBlue': accentBlue.value,
      'backgroundGray': backgroundGray.value,
      'surfaceLight': surfaceLight.value,
      'white': white.value,
      'black': black.value,
      'nearBlack': nearBlack.value,
      'goldAccent': goldAccent.value,
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
    accentBlue = const Color(0xFF2466CA);
    backgroundGray = const Color(0xFFECEDEE);
    surfaceLight = const Color(0xFFF8F9FA);
    white = const Color(0xFFFFFFFF);
    black = const Color(0xFF000000);
    nearBlack = const Color(0xFF111111);
    goldAccent = const Color(0xFFE4A319);
    error = const Color(0xFFD32F2F);
    success = const Color(0xFF2E7D32);
    warning = const Color(0xFFED6C02);
    textPrimary = const Color(0xFF212121);
    textSecondary = const Color(0xFF757575);
    divider = const Color(0xFFBDBDBD);
    roleAdmin = const Color(0xFF9C27B0);
    roleSeller = const Color(0xFF1976D2);
    roleTechnician = const Color(0xFF546E7A);
    roleClient = const Color(0xFF388E3C);

    notifier.value++;
  }
}
