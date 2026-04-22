import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/rbac_permissions_table.dart';
import '../tables/role_permissions_table.dart';

part 'rbac_permission_dao.g.dart';

@DriftAccessor(tables: [RbacPermissions, RolePermissions])
class RbacPermissionDao extends DatabaseAccessor<AppDatabase>
    with _$RbacPermissionDaoMixin {
  RbacPermissionDao(super.db);

  /// Get all permission definitions
  Future<List<RbacPermission>> getAllPermissions() =>
      (select(rbacPermissions)
            ..orderBy([
              (p) => OrderingTerm.asc(p.module),
              (p) => OrderingTerm.asc(p.name),
            ]))
          .get();

  /// Get permissions assigned to a specific role
  Future<List<RbacPermission>> getPermissionsByRole(String roleId) async {
    final query = select(rbacPermissions).join([
      innerJoin(
        rolePermissions,
        rolePermissions.permissionId.equalsExp(rbacPermissions.id),
      ),
    ])
      ..where(rolePermissions.roleId.equals(roleId))
      ..orderBy([OrderingTerm.asc(rbacPermissions.module)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(rbacPermissions)).toList();
  }

  /// Set all permissions for a role (transaction: delete old, insert new)
  Future<void> setRolePermissions(
      String roleId, List<String> permissionIds) async {
    await transaction(() async {
      await (delete(rolePermissions)
            ..where((rp) => rp.roleId.equals(roleId)))
          .go();
      for (final permId in permissionIds) {
        await into(rolePermissions).insert(RolePermissionsCompanion.insert(
          roleId: roleId,
          permissionId: permId,
        ));
      }
    });
  }

  /// Load entire role→permissions map for in-memory cache
  Future<Map<String, Set<String>>> loadAllRolePermissions() async {
    final rows = await select(rolePermissions).get();
    final map = <String, Set<String>>{};
    for (final row in rows) {
      map.putIfAbsent(row.roleId, () => {}).add(row.permissionId);
    }
    return map;
  }
}
