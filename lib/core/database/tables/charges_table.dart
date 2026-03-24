import 'package:drift/drift.dart';

class Charges extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get namaBiaya => text()();
  TextColumn get kategori => text()(); // PAJAK | LAYANAN | POTONGAN
  TextColumn get tipe => text()(); // PERSENTASE | NOMINAL
  RealColumn get nilai => real()();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  TextColumn get includeBase =>
      text().withDefault(const Constant('SUBTOTAL'))(); // SUBTOTAL | AFTER_PREVIOUS
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
