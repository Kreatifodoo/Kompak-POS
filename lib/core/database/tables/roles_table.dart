import 'package:drift/drift.dart';

class Roles extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
