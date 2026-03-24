import 'package:drift/drift.dart';

class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()(); // null = HQ/standalone, set = branch
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  RealColumn get taxRate => real().withDefault(const Constant(0.11))();
  TextColumn get currencySymbol => text().withDefault(const Constant('Rp'))();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get receiptHeader => text().nullable()();
  TextColumn get receiptFooter => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
