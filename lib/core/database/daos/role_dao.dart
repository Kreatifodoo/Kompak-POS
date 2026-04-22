import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/roles_table.dart';
import '../tables/role_permissions_table.dart';

part 'role_dao.g.dart';

@DriftAccessor(tables: [Roles, RolePermissions])
class RoleDao extends DatabaseAccessor<AppDatabase> with _$RoleDaoMixin {
  RoleDao(super.db);

  Future<List<Role>> getAllRoles() =>
      (select(roles)..orderBy([(r) => OrderingTerm.asc(r.name)])).get();

  Future<List<Role>> getSystemRoles() =>
      (select(roles)
            ..where((r) => r.isSystem.equals(true))
            ..orderBy([(r) => OrderingTerm.asc(r.name)]))
          .get();

  /// Get system roles + store-specific custom roles
  Future<List<Role>> getRolesByStore(String? storeId) {
    return (select(roles)
          ..where((r) {
            if (storeId == null) return r.isSystem.equals(true);
            return r.isSystem.equals(true) |
                r.storeId.equals(storeId) |
                r.storeId.isNull();
          })
          ..orderBy([
            (r) => OrderingTerm.desc(r.isSystem),
            (r) => OrderingTerm.asc(r.name),
          ]))
        .get();
  }

  Future<Role?> getRoleById(String id) =>
      (select(roles)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<int> insertRole(RolesCompanion role) => into(roles).insert(role);

  Future<bool> updateRole(RolesCompanion role) =>
      update(roles).replace(role);

  Future<int> deleteRole(String id) =>
      (delete(roles)..where((r) => r.id.equals(id) & r.isSystem.equals(false)))
          .go();

  Stream<List<Role>> watchRoles(String? storeId) {
    return (select(roles)
          ..where((r) {
            if (storeId == null) return r.isSystem.equals(true);
            return r.isSystem.equals(true) |
                r.storeId.equals(storeId) |
                r.storeId.isNull();
          })
          ..orderBy([
            (r) => OrderingTerm.desc(r.isSystem),
            (r) => OrderingTerm.asc(r.name),
          ]))
        .watch();
  }
}
