// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'package:tscomputer/core/services/role_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final BiometricService _biometricService = BiometricService();

  // Keys para almacenamiento seguro
  static const String _secureEmailKey = 'biometric_email';
  static const String _securePasswordKey = 'biometric_password';
  static const String _biometricEnabledKey = 'biometric_enabled';

  // 🔑 Registro con email y contraseña + datos en Firestore
  Future<User?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String id,
    required String phone,
    required String address,
  }) async {
    try {
      // 0️⃣ Validar fortaleza de contraseña antes de intentar crear
      _validatePasswordStrength(password);

      // 1️⃣ Crear usuario en Firebase Auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // 2️⃣ Guardar datos adicionales en Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'id': id, // Cédula
          'phone': phone,
          'address': address,
          'role': RoleService.CLIENT, // Rol por defecto
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });

        // 3️⃣ Enviar correo de verificación (Habilitado para seguridad)
        await user.sendEmailVerification();

        return user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'Error inesperado: $e';
    }
  }

  // 🔑 Iniciar Sesión con email y contraseña
  Future<User?> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'Error inesperado: $e';
    }
  }

  // 🔑 Recuperar contraseña
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'Error inesperado: $e';
    }
  }

  // 🚪 Cerrar Sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 👂 Escuchar cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 👤 Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // 📝 Actualizar perfil en Firestore
  Future<void> updateUserProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'phone': phone,
        'address': address,
      });
    }
  }

  // 🔒 Actualizar contraseña en Firebase Auth
  Future<void> updateUserPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  // 🔐 Validar fortaleza de contraseña
  void _validatePasswordStrength(String password) {
    if (password.length < 8) {
      throw 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw 'La contraseña debe incluir al menos un número.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw 'La contraseña debe incluir al menos una letra mayúscula.';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw 'La contraseña debe incluir al menos un carácter especial.';
    }
  }

  // 🧠 Manejo de errores comunes
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'invalid-email':
        return 'El formato del correo es inválido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      case 'operation-not-allowed':
        return 'El registro con correo/contraseña está deshabilitado.';
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      default:
        return 'Error: ${e.code}';
    }
  }

  // --- MÉTODOS PARA BIOMETRÍA ---

  /// Guarda las credenciales de forma segura para futuro uso biométrico
  Future<void> saveCredentialsForBiometrics(
    String email,
    String password,
  ) async {
    await _secureStorage.write(key: _secureEmailKey, value: email);
    await _secureStorage.write(key: _securePasswordKey, value: password);
    await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
  }

  /// Elimina las credenciales guardadas
  Future<void> disableBiometrics() async {
    await _secureStorage.delete(key: _secureEmailKey);
    await _secureStorage.delete(key: _securePasswordKey);
    await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
  }

  /// Verifica si la biometría está configurada y habilitada
  Future<bool> isBiometricAuthEnabled() async {
    final enabled = await _secureStorage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  /// Ejecuta el proceso de inicio de sesión con biometría
  Future<User?> loginWithBiometrics() async {
    try {
      // 1. Verificar si el hardware está disponible
      final available = await _biometricService.isBiometricAvailable();
      if (!available) {
        throw 'La biometría no está disponible en este dispositivo.';
      }

      // 2. Pedir autenticación al usuario
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Inicia sesión de forma rápida en TechService',
      );

      if (authenticated) {
        // 3. Recuperar credenciales del almacenamiento seguro
        final email = await _secureStorage.read(key: _secureEmailKey);
        final password = await _secureStorage.read(key: _securePasswordKey);

        if (email != null && password != null) {
          // 4. Intentar login en Firebase
          return await loginWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          throw 'No se encontraron credenciales guardadas. Inicia sesión manualmente primero.';
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica si el dispositivo tiene hardware biométrico disponible
  Future<bool> isBiometricHardwareAvailable() async {
    return await _biometricService.isBiometricAvailable();
  }
}
