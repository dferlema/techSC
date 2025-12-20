# Sistema de Tema Centralizado - TechService Pro

## 📋 Resumen

Este documento explica cómo usar el nuevo sistema de tema centralizado que permite cambiar todos los colores de la aplicación desde un solo archivo.

## 🎨 Archivo Principal: `app_theme.dart`

**Ubicación:** `lib/theme/app_theme.dart`

Este archivo contiene toda la configuración de colores y estilos de la aplicación.

### Estructura

```dart
// 1. Constantes de Color
class AppColors {
  static const Color primaryBlue = Color(0xFF0056B3);     // Azul principal
  static const Color accentOrange = Color(0xFFFFA500);    // Naranja de acento
  static const Color backgroundGray = Color(0xFFF8F9FA);  // Fondo gris claro
  // ... más colores
}

// 2. Extensión para ColorScheme
extension AppColorScheme on ColorScheme {
  Color get accentOrange => ...;    // Acceso fácil al naranja
  Color get backgroundGray => ...;  // Acceso fácil al fondo gris
}

// 3. Temas
class AppTheme {
  static ThemeData get lightTheme { ... }  // Tema claro
  static ThemeData get darkTheme { ... }   // Tema oscuro
}
```

## �� Cómo Cambiar Colores

### Opción 1: Cambiar en `AppColors`

Si quieres cambiar un color en toda la aplicación, edita la clase `AppColors`:

```dart
// lib/theme/app_theme.dart

class AppColors {
  // ✏️ Cambia estos valores para actualizar los colores
  static const Color primaryBlue = Color(0xFF0056B3);  // 👈 Cambia aquí
  static const Color accentOrange = Color(0xFFFFA500); // 👈 Cambia aquí
  static const Color backgroundGray = Color(0xFFF8F9FA); // 👈 Cambia aquí
}
```

**¡Eso es todo!** Los cambios se aplicarán automáticamente en toda la aplicación.

### Opción 2: Cambiar Estilos Específicos

Para cambiar estilos de componentes específicos (botones, tarjetas, etc.), edita el `ThemeData` correspondiente:

```dart
// En AppTheme.lightTheme
elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue,  // Color de fondo
    foregroundColor: AppColors.white,        // Color de texto
    // ... más configuración
  ),
),
```

## 💡 Cómo Usar los Colores en las Páginas

### ✅ Correcto - Usar Theme.of(context)

```dart
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  
  return Container(
    color: colorScheme.primary,           // Azul principal
    child: Icon(
      Icons.star,
      color: colorScheme.accentOrange,    // Naranja de acento
    ),
  );
}
```

### ❌ Incorrecto - Hardcodear colores

```dart
// ❌ NO HACER ESTO
Container(
  color: Color(0xFF0056B3),  // Hardcodeado - difícil de maintain
)
```

## 🔧 Colores Disponibles

### Desde `colorScheme`

```dart
colorScheme.primary          // Azul principal (#0056B3)
colorScheme.secondary        // Naranja de acento (#FFA500)
colorScheme.surface          // Superficie (blanco en light mode)
colorScheme.error            // Rojo de error
colorScheme.background       // Fondo general
```

### Desde extensión personalizada

```dart
colorScheme.accentOrange     // Naranja vibrante (#FFA500)
colorScheme.backgroundGray   // Gris muy claro (#F8F9FA)
```

### Acceso directo (solo si es necesario)

```dart
AppColors.primaryBlue
AppColors.accentOrange
AppColors.backgroundGray
```

## 📱 Soporte para Modo Oscuro

El sistema ya incluye soporte para modo oscuro. Los colores se ajustan automáticamente:

```dart
// En modo claro
colorScheme.accentOrange  // #FFA500 (naranja vibrante)

// En modo oscuro  
colorScheme.accentOrange  // #FFB74D (naranja más claro)
```

## 🚀 Ejemplo Completo

```dart
class MyCustomPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. Obtener el colorScheme del tema
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      // 2. Usar los colores del tema
      backgroundColor: colorScheme.backgroundGray,
      appBar: AppBar(
        // AppBar ya usa el tema automáticamente
        title: Text('Mi Página'),
      ),
      body: Center(
        child: ElevatedButton(
          // ElevatedButton ya usa el tema automáticamente
          onPressed: () {},
          child: Text('Botón con tema'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // FAB ya usa el tema automáticamente
        backgroundColor: colorScheme.accentOrange,  // Usar naranja
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## ✅ Beneficios

1. **Un solo punto de cambio**: Modifica colores en `app_theme.dart`
2. **Consistencia garantizada**: Todos usan los mismos colores
3. **Fácil mantenimiento**: No más búsqueda en múltiples archivos
4. **Modo oscuro incluido**: Soporte automático
5. **Escalable**: Agregar nuevos colores es simple

## 🎯 Guía Rápida de Migración

Si tienes páginas con colores hardcodeados, sigue estos pasos:

### Paso 1: Importar el tema

```dart
import '../theme/app_theme.dart';
```

### Paso 2: Obtener el colorScheme

```dart
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  // ...
}
```

### Paso 3: Reemplazar colores hardcodeados

```dart
// Antes
color: Color(0xFF0056B3)

// Después  
color: colorScheme.primary
```

## 📝 Notas Importantes

- **No hardcodees colores**: Siempre usa `Theme.of(context).colorScheme`
- **Modo oscuro**: Los colores se ajustan automáticamente
- **Componentes estándar**: AppBar, ElevatedButton, etc. ya usan el tema automáticamente
- **Colores personalizados**: Agrégalos a `AppColors` y a la extensión `AppColorScheme`

---

## 🔄 Ejemplo de Cambio Global

Para cambiar el azul principal de toda la aplicación:

1. Abre `lib/theme/app_theme.dart`
2. Cambia `AppColors.primaryBlue`:

```dart
static const Color primaryBlue = Color(0xFF00A86B); // Verde
```

3. Guarda el archivo
4. ¡Listo! Todos los elementos azules ahora son verdes 🎉
