import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/services/connectivity_service.dart';

/// Provider singleton del servicio de conectividad.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Stream que emite `true` cuando hay conexión y `false` cuando no.
///
/// Se deriva del stream de ConnectivityService para que la UI reaccione
/// a cambios en tiempo real.
final isConnectedProvider = StreamProvider<bool>((ref) {
  final service = ConnectivityService();
  // Emitir el estado actual inmediatamente
  return Stream<bool>.periodic(const Duration(seconds: 0))
      .asyncMap((_) => service.checkConnection())
      .distinct();
});

/// Estado actual de conexión (no reactive, para checks síncronos).
bool getCurrentConnectivity() {
  return ConnectivityService().isConnected;
}
