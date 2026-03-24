import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/core_providers.dart';

final chargesProvider = StreamProvider<List<Charge>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.chargeDao.watchAllByStore(storeId);
});

final activeChargesProvider = FutureProvider<List<Charge>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final svc = ref.watch(chargeServiceProvider);
  return svc.getActiveByStore(storeId);
});

final chargeDetailProvider =
    FutureProvider.family<Charge?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.chargeDao.getById(id);
});
