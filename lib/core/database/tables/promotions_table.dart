import 'package:drift/drift.dart';

class Promotions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get namaPromo => text()();
  TextColumn get deskripsi => text().nullable()();
  TextColumn get tipeProgram => text()(); // OTOMATIS | KODE_DISKON | BELI_X_GRATIS_Y
  TextColumn get kodeDiskon => text().nullable()(); // only for KODE_DISKON
  TextColumn get tipeReward => text()(); // DISKON_PERSENTASE | DISKON_NOMINAL | PRODUK_GRATIS
  RealColumn get nilaiReward => real()(); // discount % or Rp amount or free qty
  TextColumn get rewardProductId => text().nullable()(); // for PRODUK_GRATIS
  TextColumn get applyTo => text().withDefault(const Constant('ORDER'))(); // ORDER | CHEAPEST | SPECIFIC_PRODUCT
  RealColumn get maxDiskon => real().nullable()(); // max discount cap
  IntColumn get minQty => integer().withDefault(const Constant(0))(); // min items in cart
  RealColumn get minSubtotal => real().withDefault(const Constant(0))(); // min subtotal
  TextColumn get productIds => text().withDefault(const Constant(''))(); // JSON array of product IDs, empty=all
  TextColumn get categoryIds => text().withDefault(const Constant(''))(); // JSON array of category IDs, empty=all
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()(); // null = no end
  TextColumn get daysOfWeek => text().withDefault(const Constant(''))(); // JSON array e.g. [1,2,3,4,5]
  IntColumn get maxUsage => integer().withDefault(const Constant(0))(); // 0 = unlimited
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))(); // higher = applied first
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
