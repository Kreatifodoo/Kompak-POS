import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(paymentMethodServiceProvider);
  return service.getAllByStore(storeId);
});

final paymentMethodDetailProvider =
    FutureProvider.family<PaymentMethod?, String>((ref, id) async {
  final service = ref.watch(paymentMethodServiceProvider);
  return service.getById(id);
});
