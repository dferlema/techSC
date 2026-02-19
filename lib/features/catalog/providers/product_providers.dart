import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/catalog/models/product_model.dart';
import 'package:techsc/features/catalog/models/category_model.dart';

/// Provider for the search query in the products page
final productSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for the selected category ID in the products page
final productSelectedCategoryIdProvider = StateProvider<String?>((ref) => null);

/// Provider for product categories
final productCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryServiceProvider).getCategories(CategoryType.product);
});

/// Notifier that manages the filtered product list
class FilteredProducts extends FamilyAsyncNotifier<List<ProductModel>, String> {
  @override
  Future<List<ProductModel>> build(String arg) async {
    final searchQuery = ref.watch(productSearchQueryProvider).toLowerCase();
    final productService = ref.watch(productServiceProvider);

    // Fetch products once for this "Future"-based notifier
    // Note: If real-time is preferred, convert to StreamNotifier
    final products = await productService.getProducts(arg).first;

    if (searchQuery.isEmpty) return products;

    return products.where((product) {
      final name = product.name.toLowerCase();
      final desc = product.description.toLowerCase();
      return name.contains(searchQuery) || desc.contains(searchQuery);
    }).toList();
  }

  /// Manually refresh the product list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

/// Provider that returns the filtered product list based on the selected category and search query
final filteredProductsProvider =
    AsyncNotifierProvider.family<FilteredProducts, List<ProductModel>, String>(
  FilteredProducts.new,
);
