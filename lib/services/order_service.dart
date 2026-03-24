import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/config/app_config.dart';
import '../core/database/app_database.dart' hide PaymentMethod;
import '../core/utils/formatters.dart';
import '../models/cart_state_model.dart';
import '../models/enums.dart';

class OrderService {
  final AppDatabase db;
  static const _uuid = Uuid();

  OrderService(this.db);

  Future<String> createOrder({
    required CartState cart,
    required PaymentMethod paymentMethod,
    required double amountTendered,
    required String storeId,
    required String terminalId,
    required String cashierId,
    String? customerId,
    String? sessionId,
  }) async {
    final orderId = _uuid.v4();
    final paymentId = _uuid.v4();

    return await db.transaction(() async {
      // Generate order number INSIDE the transaction to prevent race conditions
      final datePrefix = Formatters.orderDatePrefix(AppConfig.orderPrefix);
      final sequence = await db.orderDao.getNextOrderSequence(datePrefix);
      final orderNumber =
          Formatters.orderNumber(AppConfig.orderPrefix, sequence);

      // Serialize charges to JSON for order storage
      final chargesJsonStr = cart.charges.isNotEmpty
          ? jsonEncode(cart.charges.map((c) => c.toJson()).toList())
          : null;

      // Serialize promotions to JSON for order storage
      final promotionsJsonStr = cart.promotions.isNotEmpty
          ? jsonEncode(cart.promotions.map((p) => p.toJson()).toList())
          : null;

      // 1. Insert order
      await db.orderDao.insertOrder(OrdersCompanion.insert(
        id: orderId,
        storeId: storeId,
        terminalId: terminalId,
        cashierId: cashierId,
        customerId: Value(customerId),
        sessionId: Value(sessionId),
        orderNumber: orderNumber,
        status: const Value('completed'),
        subtotal: cart.subtotal,
        discountAmount: Value(cart.discountAmount),
        discountType: Value(cart.discountType?.name),
        taxAmount: Value(cart.taxAmount),
        chargesJson: Value(chargesJsonStr),
        promotionsJson: Value(promotionsJsonStr),
        total: cart.total,
      ));

      // 2. Insert order items
      for (final item in cart.items) {
        // Merge extras and combo selections into extrasJson
        final extrasData = <String, dynamic>{};
        if (item.selectedExtras.isNotEmpty) {
          extrasData['extras'] = item.selectedExtras;
        }
        if (item.isCombo && item.comboSelections.isNotEmpty) {
          extrasData['isCombo'] = true;
          extrasData['comboSelections'] =
              item.comboSelections.map((s) => s.toJson()).toList();
        }

        // Lookup product cost price (HPP) for gross profit calculation
        double? itemCostPrice;
        final product = await db.productDao.getById(item.productId);
        if (product != null) {
          itemCostPrice = product.costPrice;
        }

        await db.orderDao.insertOrderItem(OrderItemsCompanion.insert(
          id: _uuid.v4(),
          orderId: orderId,
          productId: item.productId,
          productName: item.productName,
          productPrice: item.productPrice,
          quantity: item.quantity,
          extrasJson: Value(
            extrasData.isNotEmpty ? jsonEncode(extrasData) : null,
          ),
          subtotal: item.lineTotal,
          originalPrice: Value(item.originalPrice),
          costPrice: Value(itemCostPrice),
          notes: Value(item.notes),
        ));

        // 3. Decrement inventory (BOM-aware)
        if (product != null && product.hasBom) {
          // BOM product: deduct each raw material component
          final bomItems = await db.bomDao.getItemsByProduct(item.productId);
          if (bomItems.isNotEmpty) {
            for (final bom in bomItems) {
              await db.inventoryDao.decrementStock(
                bom.materialProductId,
                bom.quantity * item.quantity.toDouble(),
              );
            }
          } else {
            // hasBom=true but recipe not yet configured → fall back to
            // deducting the product itself so stock is never silently skipped.
            await db.inventoryDao.decrementStock(
              item.productId,
              item.quantity.toDouble(),
            );
          }
        } else {
          // Regular product: deduct product itself
          await db.inventoryDao.decrementStock(
            item.productId,
            item.quantity.toDouble(),
          );
        }
      }

      // 4. Insert payment
      final change = amountTendered - cart.total;
      await db.paymentDao.insertPayment(PaymentsCompanion.insert(
        id: paymentId,
        orderId: orderId,
        method: paymentMethod.name,
        amount: amountTendered,
        changeAmount: Value(change > 0 ? change : 0),
      ));

      // 5. Verify and increment promotion usage counts atomically
      for (final promo in cart.promotions) {
        final current = await db.promotionDao.getById(promo.promotionId);
        if (current != null && current.maxUsage > 0 && current.usageCount >= current.maxUsage) {
          throw Exception('Promo "${promo.namaPromo}" sudah mencapai batas penggunaan');
        }
        await db.promotionDao.incrementUsage(promo.promotionId);
      }

      // 6. Enqueue for sync
      await db.syncQueueDao.enqueue(
        targetTable: 'orders',
        recordId: orderId,
        operation: 'insert',
        payload: jsonEncode({
          'order_id': orderId,
          'order_number': orderNumber,
          'store_id': storeId,
          'total': cart.total,
          'status': 'completed',
        }),
      );

      return orderId;
    });
  }
}
