import 'package:drift/drift.dart';

class ProductExtras extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('single_select'))();
  TextColumn get optionsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
