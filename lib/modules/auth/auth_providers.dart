import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/permissions.dart';
import '../core_providers.dart';
import '../pos/cart_providers.dart' show cartProvider;
import '../rbac/rbac_providers.dart';

final currentUserProvider = StateProvider<User?>((ref) => null);
final currentStoreProvider = StateProvider<Store?>((ref) => null);
final currentStoreIdProvider = StateProvider<String?>((ref) => null);

final pinEntryProvider = StateProvider<String>((ref) => '');

final authLoadingProvider = StateProvider<bool>((ref) => false);

// BUG-AUTH-001 FIX: Use autoDispose so the provider is discarded after each
// login attempt. Without this, FutureProvider.family caches the result by PIN.
// On re-login with the same PIN after logout, the cached result is returned
// without re-running the body → providers never re-set → router redirect
// sees currentUserProvider == null → stuck on /auth with infinite loading.
final authenticateProvider = FutureProvider.autoDispose.family<User?, String>((ref, pin) async {
  final authService = ref.read(authServiceProvider);
  final db = ref.read(databaseProvider);
  final user = await authService.authenticateByPin(pin);
  if (user != null) {
    ref.read(currentUserProvider.notifier).state = user;
    await authService.saveSession(user.id, terminalId: user.terminalId);

    // Set terminal context first — terminal.storeId is authoritative
    Terminal? terminal;
    if (user.terminalId != null) {
      terminal = await db.terminalDao.getById(user.terminalId!);
      ref.read(currentTerminalProvider.notifier).state = terminal;
      ref.read(currentTerminalIdProvider.notifier).state = user.terminalId;
      await authService.setCurrentTerminalId(user.terminalId!);
    }

    // Derive storeId: prefer terminal.storeId (STRUCT-004 fix) to keep
    // store context consistent with the assigned terminal's branch.
    final effectiveStoreId = terminal?.storeId ?? user.storeId;
    if (effectiveStoreId != null) {
      ref.read(currentStoreIdProvider.notifier).state = effectiveStoreId;
      await authService.setCurrentStoreId(effectiveStoreId);
      final store = await db.storeDao.getStoreById(effectiveStoreId);
      if (store != null) {
        ref.read(currentStoreProvider.notifier).state = store;
      }
    }

    // Load RBAC permission cache
    final permCache = await ref.read(permissionCacheProvider.future);
    Permissions.updateCache(permCache);
  }
  return user;
});

/// Whether the current user is at the HQ store (parentId == null)
final isHQUserProvider = Provider<bool>((ref) {
  final store = ref.watch(currentStoreProvider);
  return store != null && store.parentId == null;
});

/// Watches branches under the current HQ store
final branchesProvider = StreamProvider<List<Store>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  final isHQ = ref.watch(isHQUserProvider);
  if (storeId == null || !isHQ) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.storeDao.watchBranches(storeId);
});

/// Selected branch filter (null = all branches)
final selectedBranchIdProvider = StateProvider<String?>((ref) => null);

/// Returns the effective list of storeIds for queries:
/// - HQ + no branch selected → HQ + all branches
/// - HQ + specific branch → [branchId]
/// - Non-HQ → [currentStoreId]
final effectiveStoreIdsProvider = FutureProvider<List<String>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final isHQ = ref.watch(isHQUserProvider);
  if (!isHQ) return [storeId];

  final selectedBranch = ref.watch(selectedBranchIdProvider);
  if (selectedBranch != null) return [selectedBranch];

  // HQ with "all branches" → return HQ + all branch IDs
  final db = ref.read(databaseProvider);
  return db.storeDao.getAllBranchIds(storeId);
});

/// BUG-AUTH-002 FIX: Centralized logout that clears ALL auth + context providers.
/// Calling sites (catalog, dashboard drawers) should use this instead of
/// manually clearing individual providers — previous code missed terminal and
/// filter providers, leaving ghost state for the next login session.
Future<void> performLogout(WidgetRef ref) async {
  ref.read(cartProvider.notifier).clearCart();
  await ref.read(authServiceProvider).clearSession();
  // User & store context
  ref.read(currentUserProvider.notifier).state = null;
  ref.read(currentStoreProvider.notifier).state = null;
  ref.read(currentStoreIdProvider.notifier).state = null;
  // Terminal context (was missing — caused ghost active-session state)
  ref.read(currentTerminalIdProvider.notifier).state = null;
  ref.read(currentTerminalProvider.notifier).state = null;
  // Report filter state (was missing — next user inherited previous filters)
  ref.read(selectedBranchIdProvider.notifier).state = null;
  ref.read(selectedTerminalFilterProvider.notifier).state = null;
  // Clear RBAC cache
  Permissions.updateCache({});
}

final restoreSessionProvider = FutureProvider<User?>((ref) async {
  final authService = ref.read(authServiceProvider);
  final db = ref.read(databaseProvider);
  final user = await authService.getCurrentUser();
  if (user != null) {
    ref.read(currentUserProvider.notifier).state = user;

    // Restore terminal context first — terminal.storeId is authoritative
    Terminal? terminal;
    if (user.terminalId != null) {
      terminal = await db.terminalDao.getById(user.terminalId!);
      ref.read(currentTerminalProvider.notifier).state = terminal;
      ref.read(currentTerminalIdProvider.notifier).state = user.terminalId;
    }

    // Derive storeId from terminal if available (STRUCT-004 fix)
    final effectiveStoreId = terminal?.storeId ?? user.storeId;
    if (effectiveStoreId != null) {
      ref.read(currentStoreIdProvider.notifier).state = effectiveStoreId;
      final store = await db.storeDao.getStoreById(effectiveStoreId);
      if (store != null) {
        ref.read(currentStoreProvider.notifier).state = store;
      }
    }

    // Load RBAC permission cache
    final permCache = await ref.read(permissionCacheProvider.future);
    Permissions.updateCache(permCache);
  }
  return user;
});
