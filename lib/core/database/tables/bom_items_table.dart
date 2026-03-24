import 'package:drift/drift.dart';

/// Bill of Materials items: maps a finished product to its raw material components.
/// Each row = "1 unit of [productId] requires [quantity] [unit] of [materialProductId]"
class BomItems extends Table {
  TextColumn get id => text()();

  /// FK → Products: the finished product that has this BOM recipe
  TextColumn get productId => text()();

  /// FK → Products: the raw material / component product
  TextColumn get materialProductId => text()();

  /// How much of the raw material is needed per 1 unit of finished product
  RealColumn get quantity => real()();

  /// Unit of measure (pcs, gram, kg, ml, liter)
  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
