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

        // 3️⃣ Opcional: Enviar correo de verificación
        // await user.sendEmailVerification();

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

  // 🚪 Cerrar Sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 👂 Escuchar cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
      default:
        return 'Error: ${e.code}';
    }
  }
}
