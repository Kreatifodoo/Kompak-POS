import 'package:drift/drift.dart';

class PosSessions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get cashierId => text()();
  TextColumn get terminalId => text()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  RealColumn get openingCash => real()();
  RealColumn get closingCash => real().nullable()();
  RealColumn get expectedCash => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
