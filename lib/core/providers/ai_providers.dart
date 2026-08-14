import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/services/ai_service.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';
import 'package:tscomputer/features/catalog/providers/product_providers.dart';

final aiServiceProvider = Provider<AiService>((ref) => AiService());

/// Provider de búsqueda semántica sobre productos de una categoría.
final aiSearchProvider =
    FutureProvider.family<List<ProductModel>, (String query, String categoryId)>(
  (ref, params) async {
    final (query, categoryId) = params;
    if (query.trim().isEmpty) {
      return ref.watch(filteredProductsProvider(categoryId)).value ?? [];
    }

    final products = await ref.watch(productServiceProvider).getProducts(categoryId).first;
    final filtered = products.where((p) {
      final q = query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) return [];

    final corpus = filtered
        .map((p) => '${p.name} ${p.description} ${p.categoryId}')
        .toList();

    final results = AiService().search(query, corpus);
    return results.map((r) => filtered[r.$1]).toList();
  },
);

/// Provider de productos similares basado en co-ocurrencia en órdenes.
final similarProductsProvider =
    FutureProvider.family<List<ProductModel>, String>(
  (ref, productId) async {
    final allProducts = await ref.watch(productsStreamProvider.future);
    final orders = await FirebaseFirestore.instance
        .collection('orders')
        .get();

    final prodCount = <String, int>{};
    final coOccur = <(String, String), int>{};

    for (final doc in orders.docs) {
      final data = doc.data();
      final items = data['items'] as List? ?? [];
      final ids = items
          .map((e) => (e as Map)['productId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      for (final id in ids) {
        prodCount[id] = (prodCount[id] ?? 0) + 1;
      }
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final key = ids[i].compareTo(ids[j]) < 0
              ? (ids[i], ids[j])
              : (ids[j], ids[i]);
          coOccur[key] = (coOccur[key] ?? 0) + 1;
        }
      }
    }

    final similarIds = AiService().similarProducts(
      productId,
      prodCount,
      coOccur,
      topK: 6,
    );

    final prodMap = {for (final p in allProducts) p.id: p};
    return similarIds.map((id) => prodMap[id]).whereType<ProductModel>().toList();
  },
);

/// Provider de sugerencias de diagnóstico basado en reservas anteriores.
final diagnosisProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, description) async {
    if (description.trim().length < 5) return [];

    final reservations = await FirebaseFirestore.instance
        .collection('reservations')
        .where('solution', isGreaterThan: '')
        .limit(100)
        .get();

    final pastCases = <(String, String)>[];
    for (final doc in reservations.docs) {
      final d = doc.data();
      final prob = (d['description'] as String? ?? '').trim();
      final sol = (d['solution'] as String? ?? '').trim();
      if (prob.isNotEmpty && sol.isNotEmpty) {
        pastCases.add((prob, sol));
      }
    }

    final results = AiService().suggestDiagnosis(description, pastCases);
    return results
        .map((r) => {
              'problem': r.$1,
              'solution': r.$2,
              'score': r.$3,
            })
        .toList();
  },
);

/// Provider del stream completo de productos (para el provider de similares).
final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  return ref.watch(productServiceProvider).getProducts('').handleError(
    (error) => debugPrint('Stream error [productsStream]: $error'),
  );
});
