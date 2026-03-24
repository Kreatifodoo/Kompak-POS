import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get pin => text()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  TextColumn get terminalId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
