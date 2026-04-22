import 'package:drift/drift.dart';

class Attendances extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get storeId => text()();
  TextColumn get terminalId => text().nullable()();
  TextColumn get type => text()(); // 'clock_in' | 'clock_out'
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  BoolColumn get isMockLocation =>
      boolean().withDefault(const Constant(false))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get photoPath => text()();
  BoolColumn get telegramSent =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
