import 'package:drift/drift.dart';

/// Combo groups define the "choices" within a combo product.
/// E.g. "Pilih Makanan", "Pilih Minuman", "Pilih Side Dish"
class ComboGroups extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()(); // FK to combo product
  TextColumn get name => text()(); // e.g. "Pilih Makanan Utama"
  IntColumn get minSelect => integer().withDefault(const Constant(1))();
  IntColumn get maxSelect => integer().withDefault(const Constant(1))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
