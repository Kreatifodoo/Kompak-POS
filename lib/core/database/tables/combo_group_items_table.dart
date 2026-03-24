import 'package:drift/drift.dart';

/// Items available within each combo group.
/// Links a combo group to its selectable products with optional extra price.
class ComboGroupItems extends Table {
  TextColumn get id => text()();
  TextColumn get comboGroupId => text()(); // FK to combo_groups
  TextColumn get productId => text()(); // FK to products (the selectable product)
  RealColumn get extraPrice => real().withDefault(const Constant(0))(); // additional cost
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
