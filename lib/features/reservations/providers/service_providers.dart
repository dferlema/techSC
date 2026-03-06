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
    extends FamilyStreamNotifier<List<ServiceModel>, String?> {
  @override
  Stream<List<ServiceModel>> build(String? arg) {
    final searchQuery = ref.watch(serviceSearchQueryProvider).toLowerCase();
    final serviceService = ref.watch(serviceServiceProvider);

    return serviceService.getServices(arg).map((services) {
      if (searchQuery.isEmpty) return services;

      return services.where((service) {
        final name = service.name.toLowerCase();
        final desc = service.description.toLowerCase();
        return name.contains(searchQuery) || desc.contains(searchQuery);
      }).toList();
    });
  }

  /// Delete a service
  Future<void> deleteService(String serviceId) async {
    final serviceService = ref.read(serviceServiceProvider);
    await serviceService.deleteService(serviceId);
  }
}

/// Provider for filtered services
final filteredServicesProvider =
    StreamNotifierProvider.family<
      FilteredServices,
      List<ServiceModel>,
      String?
    >(FilteredServices.new);
