import 'package:drift/drift.dart';

class Inventory extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get storeId => text()();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(10))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  DateTimeColumn get lastRestockAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
