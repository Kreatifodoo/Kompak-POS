import 'dart:convert';
import '../core/database/app_database.dart';
import '../models/applied_promotion_model.dart';
import '../models/cart_state_model.dart';
import '../models/enums.dart';

class PromotionService {
  final AppDatabase db;

  PromotionService(this.db);

  // ── CRUD (delegate to DAO) ──

  Future<List<Promotion>> getActiveByStore(String storeId) =>
      db.promotionDao.getActiveByStore(storeId);

  Future<Promotion?> getById(String id) =>
      db.promotionDao.getById(id);

  Future<Promotion?> validateCode(String storeId, String code) =>
      db.promotionDao.getByCode(storeId, code.toUpperCase().trim());

  Future<void> incrementUsage(String id) =>
      db.promotionDao.incrementUsage(id);

  // ── Evaluation Engine ──

  /// Evaluate all auto-apply promotions against the current cart.
  /// Returns list of applicable promotions with computed discount amounts.
  List<AppliedPromotion> evaluatePromotions({
    required List<Promotion> activePromotions,
    required CartState cart,
    required DateTime now,
    String? enteredCode,
  }) {
    final results = <AppliedPromotion>[];
    final afterDiscount = cart.subtotal - cart.discountAmount;
    if (afterDiscount <= 0) return results;

    // Sort by priority desc (higher = first)
    final sorted = List<Promotion>.from(activePromotions)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final promo in sorted) {
      final tipeProgram = PromotionTipeProgram.fromDb(promo.tipeProgram);

      // Skip KODE_DISKON if no code entered or code doesn't match
      if (tipeProgram == PromotionTipeProgram.kodeDiskon) {
        if (enteredCode == null ||
            enteredCode.toUpperCase().trim() !=
                (promo.kodeDiskon ?? '').toUpperCase().trim()) {
          continue;
        }
      }

      // Check conditions
      if (!_meetsConditions(promo, cart, now)) continue;

      // Compute reward
      final applied = _computeReward(promo, cart, afterDiscount);
      if (applied != null && applied.discountAmount > 0) {
        results.add(applied);
      }
    }

    return results;
  }

  /// Evaluate a single code-based promotion.
  AppliedPromotion? evaluateSinglePromotion({
    required Promotion promo,
    required CartState cart,
    required DateTime now,
  }) {
    if (!_meetsConditions(promo, cart, now)) return null;
    final afterDiscount = cart.subtotal - cart.discountAmount;
    if (afterDiscount <= 0) return null;
    return _computeReward(promo, cart, afterDiscount);
  }

  // ── Private Helpers ──

  bool _meetsConditions(Promotion promo, CartState cart, DateTime now) {
    // Date range check
    if (now.isBefore(promo.startDate)) return false;
    if (promo.endDate != null && now.isAfter(promo.endDate!)) return false;

    // Day of week check
    if (promo.daysOfWeek.isNotEmpty) {
      try {
        final days = (jsonDecode(promo.daysOfWeek) as List)
            .map((e) => (e as num).toInt())
            .toList();
        if (days.isNotEmpty && !days.contains(now.weekday)) return false;
      } catch (_) {
        // Invalid JSON — skip day check
      }
    }

    // Max usage check
    if (promo.maxUsage > 0 && promo.usageCount >= promo.maxUsage) return false;

    // Min qty check (total items in cart)
    final totalQty = cart.items.fold(0, (sum, item) => sum + item.quantity);
    if (promo.minQty > 0 && totalQty < promo.minQty) return false;

    // Min subtotal check
    final afterDiscount = cart.subtotal - cart.discountAmount;
    if (promo.minSubtotal > 0 && afterDiscount < promo.minSubtotal) return false;

    // Product filter check
    if (promo.productIds.isNotEmpty) {
      try {
        final requiredProducts = (jsonDecode(promo.productIds) as List)
            .map((e) => e as String)
            .toSet();
        if (requiredProducts.isNotEmpty) {
          final cartProductIds = cart.items.map((i) => i.productId).toSet();
          if (cartProductIds.intersection(requiredProducts).isEmpty) {
            return false;
          }
        }
      } catch (_) {}
    }

    // Category filter check
    // Note: CartItem doesn't have categoryId, so category filtering
    // would need product lookup. For now, skip if categoryIds is empty.
    // Category filtering is handled at config level (admin picks products).

    return true;
  }

  AppliedPromotion? _computeReward(
    Promotion promo,
    CartState cart,
    double afterDiscount,
  ) {
    final tipeReward = PromotionTipeReward.fromDb(promo.tipeReward);
    final applyTo = PromotionApplyTo.fromDb(promo.applyTo);
    double discountAmount = 0;

    switch (tipeReward) {
      case PromotionTipeReward.diskonPersentase:
        discountAmount = _computePercentageDiscount(
          promo, cart, afterDiscount, applyTo,
        );
        break;

      case PromotionTipeReward.diskonNominal:
        discountAmount = promo.nilaiReward;
        // Don't exceed the after-discount subtotal
        if (discountAmount > afterDiscount) {
          discountAmount = afterDiscount;
        }
        break;

      case PromotionTipeReward.produkGratis:
        // For free product, the discount is the product's price × qty
        // The free product must be in the cart for it to apply
        if (promo.rewardProductId != null) {
          final freeItem = cart.items.where(
              (i) => i.productId == promo.rewardProductId);
          if (freeItem.isNotEmpty) {
            final freeQty = promo.nilaiReward.toInt().clamp(0, freeItem.first.quantity);
            discountAmount = freeItem.first.productPrice * freeQty;
          }
        }
        break;
    }

    // Apply max discount cap
    if (promo.maxDiskon != null && promo.maxDiskon! > 0) {
      if (discountAmount > promo.maxDiskon!) {
        discountAmount = promo.maxDiskon!;
      }
    }

    if (discountAmount <= 0) return null;

    return AppliedPromotion(
      promotionId: promo.id,
      namaPromo: promo.namaPromo,
      tipeProgram: PromotionTipeProgram.fromDb(promo.tipeProgram),
      tipeReward: tipeReward,
      nilaiReward: promo.nilaiReward,
      applyTo: applyTo,
      discountAmount: discountAmount,
      freeProductId: tipeReward == PromotionTipeReward.produkGratis
          ? promo.rewardProductId
          : null,
      freeProductName: tipeReward == PromotionTipeReward.produkGratis
          ? cart.items
              .where((i) => i.productId == promo.rewardProductId)
              .map((i) => i.productName)
              .firstOrNull
          : null,
      freeProductQty: tipeReward == PromotionTipeReward.produkGratis
          ? promo.nilaiReward.toInt()
          : 0,
    );
  }

  double _computePercentageDiscount(
    Promotion promo,
    CartState cart,
    double afterDiscount,
    PromotionApplyTo applyTo,
  ) {
    final rate = promo.nilaiReward / 100;

    switch (applyTo) {
      case PromotionApplyTo.order:
        return afterDiscount * rate;

      case PromotionApplyTo.cheapest:
        if (cart.items.isEmpty) return 0;
        final cheapest = cart.items.reduce(
            (a, b) => a.productPrice < b.productPrice ? a : b);
        return cheapest.productPrice * rate;

      case PromotionApplyTo.specificProduct:
        // Apply to products matching productIds filter
        if (promo.productIds.isEmpty) return afterDiscount * rate;
        try {
          final targetIds = (jsonDecode(promo.productIds) as List)
              .map((e) => e as String)
              .toSet();
          if (targetIds.isEmpty) return afterDiscount * rate;
          final matchingTotal = cart.items
              .where((i) => targetIds.contains(i.productId))
              .fold(0.0, (sum, i) => sum + i.lineTotal);
          return matchingTotal * rate;
        } catch (_) {
          return afterDiscount * rate;
        }
    }
  }
}
