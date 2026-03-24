import 'package:drift/drift.dart';

class InventoryMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get type => text()(); // sale, restock, adjustment
  RealColumn get quantity => real()();
  RealColumn get previousQty => real()();
  RealColumn get newQty => real()();
  TextColumn get reason => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
