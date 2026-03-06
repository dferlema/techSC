import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/inventory/services/inventory_service.dart';
import 'package:techsc/features/inventory/models/inventory_movement_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final inventoryServiceProvider = Provider((ref) => InventoryService());

final adminInventoryQueryProvider = StateProvider<String>((ref) => '');

final adminInventoryProductsProvider = StreamProvider<List<DocumentSnapshot>>((
  ref,
) {
  final query = ref.watch(adminInventoryQueryProvider).toLowerCase();
  return FirebaseFirestore.instance.collection('products').snapshots().map((
    snapshot,
  ) {
    if (query.isEmpty) return snapshot.docs;
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return (data['name']?.toString().toLowerCase().contains(query) ??
              false) ||
          (data['description']?.toString().toLowerCase().contains(query) ??
              false);
    }).toList();
  });
});

final productMovementsProvider =
    StreamProvider.family<List<InventoryMovementModel>, String>((
      ref,
      productId,
    ) {
      final service = ref.watch(inventoryServiceProvider);
      return service.getMovementsForProduct(productId);
    });

final allMovementsProvider = StreamProvider<List<InventoryMovementModel>>((
  ref,
) {
  final service = ref.watch(inventoryServiceProvider);
  return service.getAllMovements();
});
