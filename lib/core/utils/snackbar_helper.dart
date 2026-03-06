import 'package:flutter/material.dart';

class SnackbarHelper {
  /// Muestra un SnackBar de éxito con fondo verde
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Muestra un SnackBar de error con fondo rojo, limpiando la palabra "Exception: "
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    // Limpia el prefijo 'Exception: ' para que el mensaje sea más amigable
    final cleanMessage = error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanMessage),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Muestra un SnackBar de información neutra
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
