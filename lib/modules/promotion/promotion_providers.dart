import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

final promotionsProvider = StreamProvider<List<Promotion>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.promotionDao.watchAllByStore(storeId);
});

final activePromotionsProvider = FutureProvider<List<Promotion>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final svc = ref.watch(promotionServiceProvider);
  return svc.getActiveByStore(storeId);
});

final promotionDetailProvider =
    FutureProvider.family<Promotion?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.promotionDao.getById(id);
});

// Re-export from core_providers for convenience
final promotionServiceProvider = Provider((ref) {
  return ref.watch(promotionServiceCoreProvider);
});
