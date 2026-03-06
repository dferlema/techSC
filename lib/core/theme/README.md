# 🎨 Sistema de Tema Centralizado — TechService Pro

## Estructura Real del Proyecto

```
lib/
├── core/
│   └── theme/
│       ├── app_colors.dart   ← Fuente de verdad de todos los colores
│       └── app_theme.dart    ← Configuración del ThemeData de MaterialApp
```

> [!IMPORTANT]
> Solo hay **una** fuente de verdad para los colores: `lib/core/theme/app_colors.dart`.
> Siempre importar desde `package:techsc/core/theme/app_colors.dart`.

---

## Tokens de Color Disponibles

### Colores de Marca
| Token | Descripción | Hex |
|---|---|---|
| `AppColors.primaryBlue` | Azul principal (AppBar, botones) | `#09325E` |
| `AppColors.primaryDark` | Azul más oscuro (gradientes) | `#0D47A1` |
| `AppColors.accentBlue` | Azul de acento (botones secundarios) | `#2466CA` |

### Fondos
| Token | Descripción | Hex |
|---|---|---|
| `AppColors.backgroundGray` | Fondo principal de la app (Scaffold) | `#ECEDEE` |
| `AppColors.surfaceLight` | Fondo alternativo más claro (detalles) | `#F8F9FA` |
| `AppColors.white` | Blanco (tarjetas, diálogos) | `#FFFFFF` |

### Texto
| Token | Descripción | Hex |
|---|---|---|
| `AppColors.textPrimary` | Texto principal | `#212121` |
| `AppColors.textSecondary` | Texto secundario, subtítulos | `#757575` |
| `AppColors.nearBlack` | Texto destacado (casi negro) | `#111111` |

### Estados Semánticos
| Token | Descripción | Hex |
|---|---|---|
| `AppColors.error` | Errores y acciones destructivas | `#D32F2F` |
| `AppColors.success` | Éxito y estados completados | `#2E7D32` |
| `AppColors.warning` | Advertencias y estados pendientes | `#ED6C02` |

### Otros
| Token | Descripción | Hex |
|---|---|---|
| `AppColors.divider` | Divisores y bordes | `#BDBDBD` |
| `AppColors.black` | Negro puro | `#000000` |
| `AppColors.goldAccent` | Item activo del BottomNavigationBar | `#E4A319` |
| `AppColors.whatsapp` | Verde WhatsApp (const) | `#25D366` |

### Colores por Rol
| Token | Descripción |
|---|---|
| `AppColors.roleAdmin` | Violeta `#9C27B0` |
| `AppColors.roleSeller` | Azul `#1976D2` |
| `AppColors.roleTechnician` | Azul gris `#546E7A` |
| `AppColors.roleClient` | Verde `#388E3C` |

---

## Cómo Usar Colores en Widgets

### ✅ Correcto — Usar Theme.of(context) para colores estándar

```dart
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    color: colorScheme.primary,   // AppColors.primaryBlue
    child: Text('Hola', style: TextStyle(color: colorScheme.onPrimary)),
  );
}
```

### ✅ Correcto — Usar AppColors para tokens personalizados

```dart
import 'package:techsc/core/theme/app_colors.dart';

// Para tokens que no están en colorScheme (nearBlack, surfaceLight, etc.)
Text('Título', style: TextStyle(color: AppColors.nearBlack))
Container(color: AppColors.surfaceLight)
```

### ❌ Incorrecto — Hardcodear colores

```dart
// ❌ NUNCA hacer esto
Container(color: Color(0xFF111111))  // Usar AppColors.nearBlack
Text('...', style: TextStyle(color: Color(0xFF757575)))  // Usar AppColors.textSecondary
```

> [!WARNING]
> Como `AppColors` usa variables mutables (para soportar la personalización en tiempo de ejecución),
> los tokens **no pueden usarse en contextos `const`**. Siempre quita `const` del widget padre
> si su estilo referencia un `AppColors.*`.

---

## Cambiar Colores de la App

### Desde código (valores por defecto)
Editar los valores en `app_colors.dart` y `resetToDefaults()`.

### En tiempo de ejecución (personalización de admin)
```dart
AppColors.updateColors({'primaryBlue': 0xFF00A86B});
// El ValueNotifier AppColors.notifier notificará a los listeners
```

### Desde el panel de administración
Ir a **Ajustes → Configurar Colores** (solo Admin).

---

## Agregar un Nuevo Color

1. Agregar el campo en `AppColors` con documentación
2. Agregar la entrada en `updateColors()`, `toColorMap()` y `resetToDefaults()`
3. Agregar la entrada en `_colorInfo` de `AppColorsConfigPage`
4. (Opcional) Mapear al `ColorScheme` en `AppTheme.lightTheme`
