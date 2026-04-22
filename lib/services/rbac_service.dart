import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class RbacService {
  final AppDatabase db;
  static const _uuid = Uuid();

  RbacService(this.db);

  // ── Roles ──

  Future<List<Role>> getAvailableRoles(String? storeId) =>
      db.roleDao.getRolesByStore(storeId);

  Stream<List<Role>> watchAvailableRoles(String? storeId) =>
      db.roleDao.watchRoles(storeId);

  Future<Role?> getRoleById(String id) => db.roleDao.getRoleById(id);

  Future<String> createCustomRole({
    required String name,
    required String? storeId,
    String? description,
    required List<String> permissionIds,
  }) async {
    final id = _uuid.v4();
    await db.roleDao.insertRole(RolesCompanion.insert(
      id: id,
      name: name,
      storeId: Value(storeId),
      description: Value(description),
      isSystem: const Value(false),
    ));
    await db.rbacPermissionDao.setRolePermissions(id, permissionIds);
    return id;
  }

  Future<void> updateRole({
    required String id,
    required String name,
    String? description,
    required List<String> permissionIds,
  }) async {
    final existing = await db.roleDao.getRoleById(id);
    if (existing == null) return;
    await db.roleDao.updateRole(RolesCompanion(
      id: Value(id),
      name: Value(name),
      storeId: Value(existing.storeId),
      description: Value(description),
      isSystem: Value(existing.isSystem),
      createdAt: Value(existing.createdAt),
    ));
    // Owner always gets all permissions — don't modify
    if (id != 'owner') {
      await db.rbacPermissionDao.setRolePermissions(id, permissionIds);
    }
  }

  Future<void> deleteRole(String id) async {
    final role = await db.roleDao.getRoleById(id);
    if (role == null || role.isSystem) {
      throw Exception('Tidak bisa menghapus system role');
    }
    // Reassign users with this role to 'cashier'
    await db.customStatement(
      "UPDATE users SET role = 'cashier' WHERE role = ?",
      [id],
    );
    await db.rbacPermissionDao.setRolePermissions(id, []);
    await db.roleDao.deleteRole(id);
  }

  // ── Permissions ──

  Future<Map<String, Set<String>>> loadPermissionCache() =>
      db.rbacPermissionDao.loadAllRolePermissions();

  Future<List<RbacPermission>> getAllPermissions() =>
      db.rbacPermissionDao.getAllPermissions();

  Future<List<RbacPermission>> getPermissionsForRole(String roleId) =>
      db.rbacPermissionDao.getPermissionsByRole(roleId);
}
