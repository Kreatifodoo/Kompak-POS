import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cart_item_model.dart';
import '../../models/cart_state_model.dart';
import '../../models/enums.dart';
import '../core_providers.dart';
import '../charge/charge_providers.dart';
import '../promotion/promotion_providers.dart';

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addItem(CartItem item) {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.addItem(state, item,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
    // Resolve pricelist in background after adding
    _resolvePriceForItem(item.productId);
  }

  void removeItem(int index) {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.removeItem(state, index,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
  }

  void updateQuantity(int index, int quantity) {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.updateQuantity(state, index, quantity,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
    // Re-resolve pricelist for the updated quantity
    if (index < state.items.length) {
      _resolvePriceForItem(state.items[index].productId);
    }
  }

  void applyDiscount(DiscountType type, double value) {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.applyDiscount(state, type, value,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
  }

  void clearDiscount() {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.clearDiscount(state,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
  }

  void applyPromoCode(String code) {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.applyPromoCode(state, code,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
  }

  void clearPromoCode() {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.clearPromoCode(state,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
  }

  void setCustomer(String? customerId) {
    state = state.copyWith(customerId: customerId);
  }

  void clearCustomer() {
    state = CartState(
      items: state.items,
      subtotal: state.subtotal,
      discountType: state.discountType,
      discountValue: state.discountValue,
      promotions: state.promotions,
      promotionsDiscount: state.promotionsDiscount,
      enteredPromoCode: state.enteredPromoCode,
      charges: state.charges,
      chargesTotal: state.chargesTotal,
      total: state.total,
      customerId: null,
    );
  }

  void clearCart() {
    final service = ref.read(cartServiceProvider);
    state = service.clearCart();
  }

  /// Force recalculate when charges/promotions config changes
  void recalculateCharges() {
    final service = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];
    state = service.recalculateWith(state, state.items,
        activeCharges: charges,
        chargeService: chargeSvc,
        activePromotions: promos,
        promotionService: promoSvc);
  }

  /// Resolve pricelist price for a specific product in the cart.
  Future<void> _resolvePriceForItem(String productId) async {
    final plService = ref.read(pricelistServiceProvider);
    final cartService = ref.read(cartServiceProvider);
    final chargeSvc = ref.read(chargeServiceProvider);
    final charges = ref.read(activeChargesProvider).valueOrNull ?? [];
    final promoSvc = ref.read(promotionServiceProvider);
    final promos = ref.read(activePromotionsProvider).valueOrNull ?? [];

    final idx = state.items.indexWhere((i) => i.productId == productId && !i.isCombo);
    if (idx < 0) return;

    final item = state.items[idx];
    // ISS-013: Skip pricelist for combo items (price = base + extras, not pricelist)
    if (item.isCombo) return;
    final basePrice = item.originalPrice ?? item.productPrice;

    final result = await plService.resolvePrice(
      productId: productId,
      quantity: item.quantity,
      originalPrice: basePrice,
    );

    if (result != null) {
      final items = List<CartItem>.from(state.items);
      items[idx] = item.copyWith(
        productPrice: result.tierPrice,
        originalPrice: result.originalPrice,
        savings: result.savingsPerUnit * item.quantity,
        lineTotal: result.tierPrice * item.quantity,
      );
      state = cartService.recalculateWith(state, items,
          activeCharges: charges,
          chargeService: chargeSvc,
          activePromotions: promos,
          promotionService: promoSvc);
    } else if (item.originalPrice != null) {
      final items = List<CartItem>.from(state.items);
      items[idx] = item.copyWith(
        productPrice: basePrice,
        originalPrice: basePrice,
        savings: 0,
        lineTotal: basePrice * item.quantity,
      );
      state = cartService.recalculateWith(state, items,
          activeCharges: charges,
          chargeService: chargeSvc,
          activePromotions: promos,
          promotionService: promoSvc);
    }
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).total;
});

final orderQuantityProvider = StateProvider<int>((ref) => 1);

/// Total savings across all cart items
final cartTotalSavingsProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.items.fold(0.0, (sum, item) => sum + item.savings);
});
