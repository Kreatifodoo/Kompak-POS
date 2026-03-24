import 'enums.dart';

class AppliedCharge {
  final String chargeId;
  final String namaBiaya;
  final ChargeKategori kategori;
  final ChargeTipe tipe;
  final double nilai;
  final ChargeIncludeBase includeBase;
  final double amount; // computed amount (negative for POTONGAN)

  const AppliedCharge({
    required this.chargeId,
    required this.namaBiaya,
    required this.kategori,
    required this.tipe,
    required this.nilai,
    required this.includeBase,
    required this.amount,
  });

  bool get isDeduction => kategori == ChargeKategori.potongan;

  Map<String, dynamic> toJson() => {
        'chargeId': chargeId,
        'namaBiaya': namaBiaya,
        'kategori': kategori.dbValue,
        'tipe': tipe.dbValue,
        'nilai': nilai,
        'includeBase': includeBase.dbValue,
        'amount': amount,
      };

  factory AppliedCharge.fromJson(Map<String, dynamic> json) => AppliedCharge(
        chargeId: json['chargeId'] as String,
        namaBiaya: json['namaBiaya'] as String,
        kategori: ChargeKategori.fromDb(json['kategori'] as String),
        tipe: ChargeTipe.fromDb(json['tipe'] as String),
        nilai: (json['nilai'] as num).toDouble(),
        includeBase: ChargeIncludeBase.fromDb(json['includeBase'] as String),
        amount: (json['amount'] as num).toDouble(),
      );
}
