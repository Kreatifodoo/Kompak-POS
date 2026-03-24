import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final searchQueryProvider = StateProvider<String>((ref) => '');

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(productServiceProvider);
  return service.getCategories(storeId);
});

final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(productServiceProvider);
  return service.getAllProducts(storeId);
});

final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];

  final service = ref.watch(productServiceProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  if (searchQuery.isNotEmpty) {
    return service.searchProducts(storeId, searchQuery);
  }

  if (categoryId != null) {
    return service.getByCategory(storeId, categoryId);
  }

  return service.getAllProducts(storeId);
});

final productDetailProvider = FutureProvider.family<Product?, String>((ref, id) async {
  final service = ref.watch(productServiceProvider);
  return service.getProductById(id);
});

final productExtrasProvider = FutureProvider.family<List<ProductExtra>, String>((ref, productId) async {
  final service = ref.watch(productServiceProvider);
  return service.getExtras(productId);
});

final productByBarcodeProvider = FutureProvider.family<Product?, String>((ref, barcode) async {
  final service = ref.watch(productServiceProvider);
  return service.findByBarcode(barcode);
});
