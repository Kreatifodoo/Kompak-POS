import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(customerServiceProvider);
  return service.getAllByStore(storeId);
});

final customerSearchProvider =
    FutureProvider.family<List<Customer>, String>((ref, query) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(customerServiceProvider);
  return service.searchCustomers(storeId, query);
});

final customerDetailProvider =
    FutureProvider.family<Customer?, String>((ref, id) async {
  final service = ref.watch(customerServiceProvider);
  return service.getById(id);
});
