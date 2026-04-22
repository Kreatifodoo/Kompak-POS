import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';

/// Watch all terminals for a specific store (reactive stream)
final terminalsProvider =
    StreamProvider.family<List<Terminal>, String>((ref, storeId) {
  final service = ref.watch(terminalServiceProvider);
  return service.watchByStore(storeId);
});

/// Get active terminals for a store
final activeTerminalsProvider =
    FutureProvider.family<List<Terminal>, String>((ref, storeId) {
  final service = ref.watch(terminalServiceProvider);
  return service.getActiveByStore(storeId);
});

/// Get a single terminal by ID
final terminalDetailProvider =
    FutureProvider.family<Terminal?, String>((ref, id) {
  final service = ref.watch(terminalServiceProvider);
  return service.getById(id);
});

/// All terminals across multiple store IDs (for HQ consolidated view)
final terminalsForStoreIdsProvider =
    FutureProvider.family<List<Terminal>, List<String>>((ref, storeIds) {
  final service = ref.watch(terminalServiceProvider);
  return service.getByStoreIds(storeIds);
});

/// Branch-aware active terminals for filter dropdowns and report filtering.
/// - HQ + branch selected → terminals of that branch
/// - HQ + all branches   → terminals of all branches
/// - Branch user          → terminals of current store
final branchAwareTerminalsProvider = FutureProvider<List<Terminal>>((ref) async {
  final isHQ = ref.watch(isHQUserProvider);
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];

  final service = ref.watch(terminalServiceProvider);

  if (!isHQ) {
    return service.getActiveByStore(storeId);
  }

  // HQ: respect selected branch filter
  final selectedBranch = ref.watch(selectedBranchIdProvider);
  if (selectedBranch != null) {
    return service.getActiveByStore(selectedBranch);
  }

  // HQ + all branches: get active terminals from all stores
  final db = ref.watch(databaseProvider);
  final storeIds = await db.storeDao.getAllBranchIds(storeId);
  return service.getActiveByStoreIds(storeIds);
});
