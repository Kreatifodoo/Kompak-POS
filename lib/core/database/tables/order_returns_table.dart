import 'package:drift/drift.dart';

class OrderReturns extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get storeId => text()();
  TextColumn get cashierId => text()(); // who processed the return
  TextColumn get reason => text()();
  RealColumn get returnAmount => real()(); // refund amount
  TextColumn get itemsJson => text().nullable()(); // JSON of returned items
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
