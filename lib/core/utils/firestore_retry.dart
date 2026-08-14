import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/platform/io_helper.dart';

/// Reintenta una operación de Firestore con backoff exponencial.
///
/// Solo reintent errores transitorios: `unavailable`, `deadline-exceeded`,
/// `internal`, `resource-exhausted`, `aborted`, `not-found` (red).
/// NO reintenta `permission-denied` o `unauthenticated`.
Future<T> retryFirestore<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  bool Function(Object error)? retryIf,
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;

      final shouldRetry = attempt <= maxRetries && _isRetryable(e) &&
          (retryIf == null || retryIf(e));

      if (!shouldRetry) rethrow;

      debugPrint(
          'retryFirestore: intento $attempt/$maxRetries falló (${_errorCode(e)}), '
          'reintentando en ${delay.inMilliseconds}ms...');

      await Future<void>.delayed(delay);
      delay = delay * 2; // Backoff exponencial: 500ms → 1s → 2s
    }
  }
}

/// Errores de Firestore que se consideran transitorios (red/timeouts).
bool _isRetryable(Object error) {
  if (error is FirebaseException) {
    const retryableCodes = {
      'unavailable',
      'deadline-exceeded',
      'internal',
      'resource-exhausted',
      'aborted',
      'not-found',
      'data-loss',
    };
    return retryableCodes.contains(error.code);
  }
  // Errores de socket/conexión
  if (isRetryableNetworkError(error) || error is TimeoutException) return true;
  if (error.toString().contains('PERMISSION_DENIED')) return false;
  if (error.toString().contains('UNAUTHENTICATED')) return false;
  return false;
}

String _errorCode(Object error) {
  if (error is FirebaseException) return error.code;
  return error.runtimeType.toString();
}
