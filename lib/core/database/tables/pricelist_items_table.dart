import 'package:drift/drift.dart';

class PricelistItems extends Table {
  TextColumn get id => text()();
  TextColumn get pricelistId => text()();
  TextColumn get productId => text()();
  IntColumn get minQty => integer().withDefault(const Constant(1))();
  IntColumn get maxQty => integer().withDefault(const Constant(0))();
  RealColumn get price => real()();

  @override
  Set<Column> get primaryKey => {id};
}
