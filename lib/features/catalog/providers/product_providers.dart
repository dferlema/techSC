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
class FilteredProducts
    extends FamilyStreamNotifier<List<ProductModel>, String> {
  @override
  Stream<List<ProductModel>> build(String arg) {
    final searchQuery = ref.watch(productSearchQueryProvider).toLowerCase();
    final productService = ref.watch(productServiceProvider);

    return productService.getProducts(arg).map((products) {
      if (searchQuery.isEmpty) return products;

      return products.where((product) {
        final name = product.name.toLowerCase();
        final desc = product.description.toLowerCase();
        return name.contains(searchQuery) || desc.contains(searchQuery);
      }).toList();
    });
  }
}

/// Provider that returns the filtered product list based on the selected category and search query
final filteredProductsProvider =
    StreamNotifierProvider.family<FilteredProducts, List<ProductModel>, String>(
      FilteredProducts.new,
    );
