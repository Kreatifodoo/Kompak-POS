import 'enums.dart';

class AppliedPromotion {
  final String promotionId;
  final String namaPromo;
  final PromotionTipeProgram tipeProgram;
  final PromotionTipeReward tipeReward;
  final double nilaiReward;
  final PromotionApplyTo applyTo;
  final double discountAmount; // computed discount (always positive)
  final String? freeProductId;
  final String? freeProductName;
  final int freeProductQty;

  const AppliedPromotion({
    required this.promotionId,
    required this.namaPromo,
    required this.tipeProgram,
    required this.tipeReward,
    required this.nilaiReward,
    required this.applyTo,
    required this.discountAmount,
    this.freeProductId,
    this.freeProductName,
    this.freeProductQty = 0,
  });

  bool get isFreeProduct => tipeReward == PromotionTipeReward.produkGratis;

  Map<String, dynamic> toJson() => {
        'promotionId': promotionId,
        'namaPromo': namaPromo,
        'tipeProgram': tipeProgram.dbValue,
        'tipeReward': tipeReward.dbValue,
        'nilaiReward': nilaiReward,
        'applyTo': applyTo.dbValue,
        'discountAmount': discountAmount,
        'freeProductId': freeProductId,
        'freeProductName': freeProductName,
        'freeProductQty': freeProductQty,
      };

  factory AppliedPromotion.fromJson(Map<String, dynamic> json) =>
      AppliedPromotion(
        promotionId: json['promotionId'] as String,
        namaPromo: json['namaPromo'] as String,
        tipeProgram:
            PromotionTipeProgram.fromDb(json['tipeProgram'] as String),
        tipeReward:
            PromotionTipeReward.fromDb(json['tipeReward'] as String),
        nilaiReward: (json['nilaiReward'] as num).toDouble(),
        applyTo: PromotionApplyTo.fromDb(json['applyTo'] as String),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        freeProductId: json['freeProductId'] as String?,
        freeProductName: json['freeProductName'] as String?,
        freeProductQty: (json['freeProductQty'] as num?)?.toInt() ?? 0,
      );
}
