import '../core/database/app_database.dart' show Charge, Promotion;
import '../models/applied_charge_model.dart';
import '../models/applied_promotion_model.dart';
import '../models/cart_item_model.dart';
import '../models/cart_state_model.dart';
import '../models/enums.dart';
import 'charge_service.dart';
import 'promotion_service.dart';

class CartService {
  CartState addItem(
    CartState state,
    CartItem newItem, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    final items = List<CartItem>.from(state.items);

    // Combo items are always added as separate lines (different selections)
    if (newItem.isCombo) {
      items.add(newItem);
    } else {
      final existingIndex = items.indexWhere(
        (item) => item.productId == newItem.productId && !item.isCombo,
      );

      if (existingIndex >= 0) {
        final existing = items[existingIndex];
        final updatedQty = existing.quantity + newItem.quantity;
        items[existingIndex] = existing.copyWith(
          quantity: updatedQty,
          lineTotal: existing.productPrice * updatedQty,
        );
      } else {
        items.add(newItem);
      }
    }

    return _recalculate(
      state.copyWith(items: items),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState removeItem(
    CartState state,
    int index, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    final items = List<CartItem>.from(state.items);
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
    }
    return _recalculate(
      state.copyWith(items: items),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState updateQuantity(
    CartState state,
    int index,
    int newQuantity, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    final items = List<CartItem>.from(state.items);
    if (index >= 0 && index < items.length) {
      if (newQuantity <= 0) {
        items.removeAt(index);
      } else {
        final item = items[index];
        items[index] = item.copyWith(
          quantity: newQuantity,
          lineTotal: item.productPrice * newQuantity,
        );
      }
    }
    return _recalculate(
      state.copyWith(items: items),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState applyDiscount(
    CartState state,
    DiscountType type,
    double value, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    return _recalculate(
      state.copyWith(discountType: type, discountValue: value),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState clearDiscount(
    CartState state, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    return _recalculate(
      state.copyWith(clearDiscount: true),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState applyPromoCode(
    CartState state,
    String code, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    return _recalculate(
      state.copyWith(enteredPromoCode: code),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState clearPromoCode(
    CartState state, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    return _recalculate(
      state.copyWith(clearPromoCode: true),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState clearCart() {
    return const CartState();
  }

  /// Recalculate totals with externally-modified items list.
  CartState recalculateWith(
    CartState state,
    List<CartItem> items, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    return _recalculate(
      state.copyWith(items: items),
      activeCharges: activeCharges,
      chargeService: chargeService,
      activePromotions: activePromotions,
      promotionService: promotionService,
    );
  }

  CartState _recalculate(
    CartState state, {
    List<Charge>? activeCharges,
    ChargeService? chargeService,
    List<Promotion>? activePromotions,
    PromotionService? promotionService,
  }) {
    final subtotal =
        state.items.fold(0.0, (sum, item) => sum + item.lineTotal);

    // 1. Manual discount
    double discountAmount = 0;
    if (state.discountType != null) {
      if (state.discountType == DiscountType.percentage) {
        discountAmount = subtotal * (state.discountValue / 100);
      } else {
        discountAmount = state.discountValue;
      }
    }

    final afterDiscount = subtotal - discountAmount;

    // 2. Promotions (after manual discount, before charges)
    List<AppliedPromotion> appliedPromotions = [];
    double promotionsDiscount = 0;

    if (promotionService != null &&
        activePromotions != null &&
        activePromotions.isNotEmpty &&
        state.items.isNotEmpty) {
      // Create a temporary state for evaluation
      final evalState = state.copyWith(
        subtotal: subtotal,
        discountType: state.discountType,
        discountValue: state.discountValue,
      );
      appliedPromotions = promotionService.evaluatePromotions(
        activePromotions: activePromotions,
        cart: evalState,
        now: DateTime.now(),
        enteredCode: state.enteredPromoCode,
      );
      promotionsDiscount =
          appliedPromotions.fold(0.0, (sum, p) => sum + p.discountAmount);
    }

    final afterPromotions = afterDiscount - promotionsDiscount;

    // 3. Charges (after promotions)
    List<AppliedCharge> appliedCharges = [];
    double chargesTotal = 0;

    if (chargeService != null &&
        activeCharges != null &&
        activeCharges.isNotEmpty) {
      appliedCharges =
          chargeService.computeCharges(activeCharges, afterPromotions);
      chargesTotal =
          appliedCharges.fold(0.0, (sum, c) => sum + c.amount);
    }

    final total = afterPromotions + chargesTotal;

    return state.copyWith(
      subtotal: subtotal,
      promotions: appliedPromotions,
      promotionsDiscount: promotionsDiscount,
      charges: appliedCharges,
      chargesTotal: chargesTotal,
      total: total > 0 ? total : 0,
    );
  }
}
