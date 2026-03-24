import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core_providers.dart';

final syncPendingCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db.syncQueueDao.watchPendingCount();
});

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

final isSyncingProvider = StateProvider<bool>((ref) => false);
