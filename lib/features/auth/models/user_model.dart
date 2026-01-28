import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/role_service.dart';

/// Modelo de datos para representar un usuario en el sistema
class UserModel {
  final String uid; // ID único de Firebase Auth
  final String name; // Nombre completo
  final String email; // Correo electrónico
  final String phone; // Número de WhatsApp/Celular
  final String address; // Dirección de entrega
  final String role; // Rol (cliente, vendedor, admin, técnico)
  final String id; // Cédula o ID nacional
  final DateTime? createdAt; // Fecha de registro

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.id,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      role: data['role'] ?? RoleService.CLIENT,
      id: data['id'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
      'id': id,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}
