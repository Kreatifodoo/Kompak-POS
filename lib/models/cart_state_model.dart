import 'cart_item_model.dart';
import 'applied_charge_model.dart';
import 'applied_promotion_model.dart';
import 'enums.dart';

class CartState {
  final List<CartItem> items;
  final double subtotal;
  final DiscountType? discountType;
  final double discountValue;
  final List<AppliedPromotion> promotions;
  final double promotionsDiscount;
  final String? enteredPromoCode;
  final List<AppliedCharge> charges;
  final double chargesTotal;
  final double total;
  final String? customerId;

  const CartState({
    this.items = const [],
    this.subtotal = 0,
    this.discountType,
    this.discountValue = 0,
    this.promotions = const [],
    this.promotionsDiscount = 0,
    this.enteredPromoCode,
    this.charges = const [],
    this.chargesTotal = 0,
    this.total = 0,
    this.customerId,
  });

  double get discountAmount {
    if (discountType == null) return 0;
    if (discountType == DiscountType.percentage) {
      return subtotal * (discountValue / 100);
    }
    // BUG-MULTI-005 FIX: Cap nominal discount to subtotal so stored
    // discountAmount never exceeds the order total.
    return discountValue > subtotal ? subtotal : discountValue;
  }

  /// Backward-compat: effective tax rate from PAJAK charges
  double get taxRate {
    final pajak = charges.where((c) => c.kategori == ChargeKategori.pajak);
    if (pajak.isEmpty) return 0;
    final afterDiscount = subtotal - discountAmount;
    if (afterDiscount <= 0) return 0;
    final pajakTotal = pajak.fold(0.0, (sum, c) => sum + c.amount);
    return pajakTotal / afterDiscount;
  }

  /// Backward-compat: total tax amount from PAJAK charges
  double get taxAmount {
    return charges
        .where((c) => c.kategori == ChargeKategori.pajak)
        .fold(0.0, (sum, c) => sum + c.amount);
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    double? subtotal,
    DiscountType? discountType,
    double? discountValue,
    List<AppliedPromotion>? promotions,
    double? promotionsDiscount,
    String? enteredPromoCode,
    List<AppliedCharge>? charges,
    double? chargesTotal,
    double? total,
    String? customerId,
    bool clearDiscount = false,
    bool clearPromoCode = false,
  }) {
    return CartState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountType:
          clearDiscount ? null : (discountType ?? this.discountType),
      discountValue:
          clearDiscount ? 0 : (discountValue ?? this.discountValue),
      promotions: promotions ?? this.promotions,
      promotionsDiscount: promotionsDiscount ?? this.promotionsDiscount,
      enteredPromoCode:
          clearPromoCode ? null : (enteredPromoCode ?? this.enteredPromoCode),
      charges: charges ?? this.charges,
      chargesTotal: chargesTotal ?? this.chargesTotal,
      total: total ?? this.total,
      customerId: customerId ?? this.customerId,
    );
  }
}
