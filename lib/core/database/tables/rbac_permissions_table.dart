import 'package:drift/drift.dart';

class RbacPermissions extends Table {
  TextColumn get id => text()();
  TextColumn get module => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
