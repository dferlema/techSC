// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
          'role': 'cliente', // Rol por defecto
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
}
