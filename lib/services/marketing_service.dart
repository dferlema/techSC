import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'role_service.dart';

class MarketingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all users with the role 'cliente'
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

  /// Fetches a list of all products for the campaign selection
  /// (We use the same products collection)
  Stream<QuerySnapshot> getAvailableProducts() {
    return _firestore.collection('products').snapshots();
  }

  /// Optional: Track campaign history
  Future<void> logPromotionSent({
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
