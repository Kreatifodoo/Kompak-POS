import 'package:drift/drift.dart';

class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  RealColumn get productPrice => real()();
  IntColumn get quantity => integer()();
  TextColumn get extrasJson => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get originalPrice => real().nullable()();
  RealColumn get costPrice => real().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
