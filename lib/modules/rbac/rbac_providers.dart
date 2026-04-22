import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../services/rbac_service.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

/// RBAC service instance
final rbacServiceProvider = Provider<RbacService>((ref) {
  return RbacService(ref.watch(databaseProvider));
});

/// The core permission cache: Map<roleId, Set<permissionId>>
/// Loaded once, invalidated when role_permissions change.
final permissionCacheProvider =
    FutureProvider<Map<String, Set<String>>>((ref) async {
  final service = ref.read(rbacServiceProvider);
  return service.loadPermissionCache();
});

/// All permission definitions (for role form checkbox grid)
final allPermissionsProvider =
    FutureProvider<List<RbacPermission>>((ref) async {
  final service = ref.read(rbacServiceProvider);
  return service.getAllPermissions();
});

/// Available roles for a store (system + custom)
final availableRolesProvider =
    StreamProvider.family<List<Role>, String?>((ref, storeId) {
  final service = ref.watch(rbacServiceProvider);
  return service.watchAvailableRoles(storeId);
});

/// Permissions assigned to a specific role (for role edit form)
final rolePermissionsProvider =
    FutureProvider.family<List<RbacPermission>, String>((ref, roleId) {
  final service = ref.read(rbacServiceProvider);
  return service.getPermissionsForRole(roleId);
});

/// Helper: check if current user's role has a specific permission
final hasPermissionProvider = Provider.family<bool, String>((ref, permissionId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.role == 'owner') return true;
  final cacheAsync = ref.watch(permissionCacheProvider);
  return cacheAsync.when(
    data: (cache) => cache[user.role]?.contains(permissionId) ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});
