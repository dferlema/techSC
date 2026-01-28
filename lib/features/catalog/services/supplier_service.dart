import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:techsc/features/catalog/models/supplier_model.dart';

/// Servicio para gestionar proveedores en Firestore.
///
/// Proporciona operaciones CRUD (Crear, Leer, Actualizar, Eliminar)
/// para la colección de proveedores.
class SupplierService {
  static final SupplierService _instance = SupplierService._internal();
  factory SupplierService() => _instance;
  SupplierService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'suppliers';

  /// Obtiene un stream de todos los proveedores ordenados por nombre
  Stream<List<SupplierModel>> getSuppliers() {
    return _firestore.collection(_collection).orderBy('name').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Obtiene un proveedor específico por ID
  Future<SupplierModel?> getSupplierById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return SupplierModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo proveedor: $e');
      return null;
    }
  }

  /// Agrega un nuevo proveedor
  Future<String?> addSupplier(SupplierModel supplier) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(supplier.toMap());
      debugPrint('Proveedor creado con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error agregando proveedor: $e');
      rethrow;
    }
  }

  /// Actualiza un proveedor existente
  Future<void> updateSupplier(SupplierModel supplier) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(supplier.id)
          .update(supplier.toMap());
      debugPrint('Proveedor actualizado: ${supplier.id}');
    } catch (e) {
      debugPrint('Error actualizando proveedor: $e');
      rethrow;
    }
  }

  /// Elimina un proveedor
  Future<void> deleteSupplier(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      debugPrint('Proveedor eliminado: $id');
    } catch (e) {
      debugPrint('Error eliminando proveedor: $e');
      rethrow;
    }
  }

  /// Verifica si existe un proveedor con el mismo nombre
  Future<bool> supplierNameExists(String name, {String? excludeId}) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('name', isEqualTo: name)
          .get();

      if (excludeId != null) {
        return query.docs.any((doc) => doc.id != excludeId);
      }

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando nombre de proveedor: $e');
      return false;
    }
  }
}
