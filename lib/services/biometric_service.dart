import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Servicio encargado de manejar la autenticación biométrica (Huella/Rostro)
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica si el dispositivo cuenta con hardware biométrico
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      print('Error validando disponibilidad biométrica: $e');
      return false;
    }
  }

  /// Obtiene la lista de biometrías disponibles (Fingerprint, Face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Error obteniendo tipos de biometría: $e');
      return <BiometricType>[];
    }
  }

  /// Ejecuta el prompt de autenticación biométrica
  /// [localizedReason] es el mensaje que se muestra al usuario (específico para iOS)
  Future<bool> authenticate({
    String localizedReason = 'Por favor, autentícate para acceder',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Forzamos a que sea biométrico, no PIN/Patrón
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Error en autenticación biométrica: $e');
      return false;
    }
  }
}
