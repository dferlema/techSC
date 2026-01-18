import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/config_model.dart';

/// Service to manage app-wide configuration settings (Company name, phone, VAT, etc.).
class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'config';
  final String _docId = 'company_info';

  // --- Company Info Methods ---

  /// Returns a stream of the current configuration from Firestore.
  /// If no config exists, it returns a default [ConfigModel].
  Stream<ConfigModel> getConfigStream() {
    return _firestore.collection(_collection).doc(_docId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        return ConfigModel();
      }
      return ConfigModel.fromMap(doc.data()!);
    });
  }

  Future<ConfigModel> getConfig() async {
    final doc = await _firestore.collection(_collection).doc(_docId).get();
    if (!doc.exists) {
      return ConfigModel();
    }
    return ConfigModel.fromMap(doc.data()!);
  }

  Future<void> updateConfig(ConfigModel config) async {
    await _firestore
        .collection(_collection)
        .doc(_docId)
        .set(config.toMap(), SetOptions(merge: true));
  }

  // --- Banner Methods ---

  Stream<QuerySnapshot> getBannersStream() {
    return _firestore.collection('banners').snapshots();
  }

  Future<void> addBanner(File imageFile) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('banners').child(fileName);
      await ref.putFile(imageFile);
      final String downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('banners').add({
        'imageUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding banner: $e');
      rethrow;
    }
  }

  Future<void> deleteBanner(String docId, String imageUrl) async {
    try {
      // 1. Delete from Storage
      try {
        final Reference ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      } catch (e) {
        print('Error deleting image from storage: $e');
        // Continue to delete document even if storage delete fails
      }

      // 2. Delete from Firestore
      await _firestore.collection('banners').doc(docId).delete();
    } catch (e) {
      print('Error deleting banner: $e');
      rethrow;
    }
  }
}
