import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/platform/io_helper.dart';

/// Servicio central de monitoreo de conectividad.
///
/// Verifica tanto el tipo de red (WiFi/móvil) como el acceso real a Internet.
/// Expone un stream para que la UI y los servicios reaccionen a cambios.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  ConnectivityService._();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _isConnected = true;
  StreamSubscription? _subscription;

  /// Stream que emite `true` cuando hay conexión y `false` cuando no.
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Estado actual de conexión (síncrono).
  bool get isConnected => _isConnected;

  /// Inicializa el listener de conectividad. Llamar una vez en `main()`.
  void initialize() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _checkActualConnection(results);
    });
    // Verificar estado actual al iniciar
    _connectivity.checkConnectivity().then(_checkActualConnection);
  }

  Future<void> _checkActualConnection(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.first == ConnectivityResult.none) {
      _updateConnection(false);
      return;
    }
    // Verificar acceso real a Internet (no solo WiFi/móvil)
    final hasInternet = await _hasRealInternetAccess();
    _updateConnection(hasInternet);
  }

  void _updateConnection(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionController.add(connected);
      debugPrint('Connectivity: ${connected ? "ONLINE" : "OFFLINE"}');
    }
  }

  /// Verifica acceso real a Internet.
  Future<bool> _hasRealInternetAccess() async {
    return hasInternetConnection();
  }

  /// Verificación manual de conexión (para pull-to-refresh, etc.).
  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    await _checkActualConnection(results);
    return _isConnected;
  }

  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}
