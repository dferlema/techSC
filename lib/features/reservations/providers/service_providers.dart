import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/reservations/models/service_model.dart';
import 'package:techsc/features/catalog/models/category_model.dart';

/// Provider for the search query in the services page
final serviceSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for the selected category ID in the services page
final serviceSelectedCategoryIdProvider = StateProvider<String?>((ref) => null);

/// Provider for service categories
final serviceCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryServiceProvider).getCategories(CategoryType.service);
});

/// Notifier that manages the filtered services list
class FilteredServices
    extends FamilyAsyncNotifier<List<ServiceModel>, String?> {
  @override
  Future<List<ServiceModel>> build(String? arg) async {
    final searchQuery = ref.watch(serviceSearchQueryProvider).toLowerCase();
    final serviceService = ref.watch(serviceServiceProvider);

    // Fetch services once for this "Future"-based notifier
    final services = await serviceService.getServices(arg).first;

    if (searchQuery.isEmpty) return services;

    return services.where((service) {
      final name = service.name.toLowerCase();
      final desc = service.description.toLowerCase();
      return name.contains(searchQuery) || desc.contains(searchQuery);
    }).toList();
  }

  /// Manually refresh the services list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

/// Provider for filtered services
final filteredServicesProvider =
    AsyncNotifierProvider.family<FilteredServices, List<ServiceModel>, String?>(
      FilteredServices.new,
    );
