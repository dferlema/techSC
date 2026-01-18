import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'role_service.dart';

/// Servicio para gestionar operaciones de Marketing
/// Maneja la obtención de clientes y productos desde Firestore
class MarketingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene un flujo de clientes (usuarios con rol 'cliente')
  Stream<List<UserModel>> getClients() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: RoleService.CLIENT)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Obtiene los productos disponibles para promocionar
  Stream<QuerySnapshot> getAvailableProducts() {
    return _firestore.collection('products').snapshots();
  }

  /// Registra un mensaje de marketing enviado (Opcional para historial futuro)
  Future<void> logMarketingMessage({
    required String productId,
    required String clientUid,
    required String sentBy,
  }) async {
    try {
      await _firestore.collection('marketing_logs').add({
        'productId': productId,
        'clientUid': clientUid,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': sentBy,
      });
    } catch (e) {
      debugPrint('Error logging promotion: $e');
    }
  }
}
