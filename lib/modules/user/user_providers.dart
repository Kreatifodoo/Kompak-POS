import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

final usersProvider = FutureProvider<List<User>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(userServiceProvider);
  return service.getUsersByStore(storeId);
});

final userDetailProvider =
    FutureProvider.family<User?, String>((ref, id) async {
  final service = ref.watch(userServiceProvider);
  return service.getUserById(id);
});
