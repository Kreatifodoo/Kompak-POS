import 'package:drift/drift.dart';

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get method => text()();
  RealColumn get amount => real()();
  RealColumn get changeAmount => real().withDefault(const Constant(0))();
  TextColumn get referenceNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
