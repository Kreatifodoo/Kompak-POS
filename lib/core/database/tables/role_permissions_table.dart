import 'package:drift/drift.dart';

class RolePermissions extends Table {
  TextColumn get roleId => text()();
  TextColumn get permissionId => text()();

  @override
  Set<Column> get primaryKey => {roleId, permissionId};
}
