import 'package:drift/drift.dart';

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get terminalId => text()();
  TextColumn get cashierId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get orderNumber => text()();
  TextColumn get status => text().withDefault(const Constant('confirmed'))();
  RealColumn get subtotal => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  TextColumn get discountType => text().nullable()();
  RealColumn get taxAmount => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  TextColumn get chargesJson => text().nullable()();
  TextColumn get promotionsJson => text().nullable()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{orderNumber}];
}
