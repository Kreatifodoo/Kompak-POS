import 'dart:convert';
import '../core/database/app_database.dart';
import '../core/utils/formatters.dart';
import '../models/applied_charge_model.dart';
import '../models/applied_promotion_model.dart';
import '../models/cart_item_model.dart';
import '../models/enums.dart';
import '../models/session_report_model.dart';

/// Generates HTML receipt content for browser printing (web only).
/// On web, thermal printing is replaced with browser's window.print().
class WebPrintService {
  /// Generate receipt HTML for browser print
  static String generateReceiptHtml({
    required String storeName,
    required String storeAddress,
    required String cashierName,
    required Order order,
    required List<OrderItem> items,
    required Payment payment,
    String? customerName,
    String? receiptHeader,
    String? receiptFooter,
  }) {
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html><html><head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln('<title>Receipt - ${order.orderNumber}</title>');
    buf.writeln('<style>');
    buf.writeln(_receiptCss);
    buf.writeln('</style></head><body>');

    // Header
    buf.writeln('<div class="receipt">');
    buf.writeln('<h1>${_esc(storeName.toUpperCase())}</h1>');
    if (storeAddress.isNotEmpty) {
      buf.writeln('<p class="center">${_esc(storeAddress)}</p>');
    }
    if (receiptHeader != null && receiptHeader.isNotEmpty) {
      buf.writeln('<p class="center">${_esc(receiptHeader)}</p>');
    }
    buf.writeln('<hr class="double">');

    // Order info
    buf.writeln('<p>Order: ${_esc(order.orderNumber)}</p>');
    buf.writeln('<p>Date: ${Formatters.dateTime(order.createdAt)}</p>');
    buf.writeln('<p>Cashier: ${_esc(cashierName)}</p>');
    if (customerName != null && customerName.isNotEmpty) {
      buf.writeln('<p>Customer: ${_esc(customerName)}</p>');
    }
    buf.writeln('<hr>');

    // Items table
    buf.writeln('<table>');
    buf.writeln('<tr><th class="left">Item</th><th>Qty</th><th class="right">Amount</th></tr>');
    for (final item in items) {
      buf.writeln('<tr>');
      buf.writeln('<td>${_esc(item.productName)}</td>');
      buf.writeln('<td class="center">${item.quantity}</td>');
      buf.writeln('<td class="right">${Formatters.currencyCompact(item.subtotal)}</td>');
      buf.writeln('</tr>');

      // Combo selections
      if (item.extrasJson != null && item.extrasJson!.isNotEmpty) {
        try {
          final extras = jsonDecode(item.extrasJson!) as Map<String, dynamic>;
          if (extras['isCombo'] == true) {
            final selections = (extras['comboSelections'] as List<dynamic>?) ?? [];
            for (final selJson in selections) {
              final sel = ComboSelection.fromJson(selJson as Map<String, dynamic>);
              final extraLabel = sel.extraPrice > 0
                  ? ' (+${Formatters.currencyCompact(sel.extraPrice)})'
                  : '';
              buf.writeln('<tr><td colspan="3" class="sub-item">* ${_esc(sel.productName)}$extraLabel</td></tr>');
            }
          }
        } catch (_) {}
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        for (final line in item.notes!.split('\n')) {
          if (line.trim().isNotEmpty) {
            buf.writeln('<tr><td colspan="3" class="sub-item">>> ${_esc(line)}</td></tr>');
          }
        }
      }

      // Savings
      if (item.originalPrice != null && item.originalPrice! > item.productPrice) {
        final itemSavings = (item.originalPrice! - item.productPrice) * item.quantity;
        buf.writeln('<tr><td colspan="3" class="sub-item">Hemat: ${Formatters.currencyCompact(itemSavings)}</td></tr>');
      }
    }
    buf.writeln('</table>');
    buf.writeln('<hr>');

    // Totals
    buf.writeln('<table class="totals">');
    buf.writeln('<tr><td>Subtotal</td><td class="right">${Formatters.currencyCompact(order.subtotal)}</td></tr>');

    if (order.discountAmount > 0) {
      buf.writeln('<tr><td>Discount</td><td class="right">-${Formatters.currencyCompact(order.discountAmount)}</td></tr>');
    }

    // Promotions
    if (order.promotionsJson != null && order.promotionsJson!.isNotEmpty) {
      final promoList = (jsonDecode(order.promotionsJson!) as List)
          .map((e) => AppliedPromotion.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final promo in promoList) {
        final label = promo.tipeReward == PromotionTipeReward.diskonPersentase
            ? '${promo.namaPromo} ${promo.nilaiReward.toStringAsFixed(promo.nilaiReward.truncateToDouble() == promo.nilaiReward ? 0 : 1)}%'
            : promo.namaPromo;
        buf.writeln('<tr><td>${_esc(label)}</td><td class="right">-${Formatters.currencyCompact(promo.discountAmount)}</td></tr>');
      }
    }

    // Charges
    if (order.chargesJson != null && order.chargesJson!.isNotEmpty) {
      final chargesList = (jsonDecode(order.chargesJson!) as List)
          .map((e) => AppliedCharge.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final charge in chargesList) {
        final label = charge.tipe == ChargeTipe.persentase
            ? '${charge.namaBiaya} ${charge.nilai.toStringAsFixed(charge.nilai.truncateToDouble() == charge.nilai ? 0 : 1)}%'
            : charge.namaBiaya;
        final prefix = charge.isDeduction ? '-' : '';
        buf.writeln('<tr><td>${_esc(label)}</td><td class="right">$prefix${Formatters.currencyCompact(charge.amount.abs())}</td></tr>');
      }
    } else if (order.taxAmount > 0) {
      buf.writeln('<tr><td>Tax</td><td class="right">${Formatters.currencyCompact(order.taxAmount)}</td></tr>');
    }

    buf.writeln('</table>');
    buf.writeln('<hr class="double">');

    // Total
    buf.writeln('<div class="total-row"><span>TOTAL</span><span>${Formatters.currency(order.total)}</span></div>');
    buf.writeln('<hr class="double">');

    // Payment
    buf.writeln('<p>Payment: ${payment.method.toUpperCase()}</p>');
    if (payment.method == 'cash') {
      buf.writeln('<p>Tendered: ${Formatters.currency(payment.amount)}</p>');
      buf.writeln('<p>Change: ${Formatters.currency(payment.changeAmount)}</p>');
    }
    buf.writeln('<hr class="double">');

    // Savings — pricelist savings + promotion discounts
    double totalSavings = items.fold<double>(0, (sum, item) {
      if (item.originalPrice != null && item.originalPrice! > item.productPrice) {
        return sum + (item.originalPrice! - item.productPrice) * item.quantity;
      }
      return sum;
    });
    // Add promotion discounts
    if (order.promotionsJson != null && order.promotionsJson!.isNotEmpty) {
      final promoList = (jsonDecode(order.promotionsJson!) as List)
          .map((e) => AppliedPromotion.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final promo in promoList) {
        totalSavings += promo.discountAmount;
      }
    }
    if (totalSavings > 0) {
      buf.writeln('<p class="center bold">Anda hemat ${Formatters.currency(totalSavings)}</p>');
      buf.writeln('<hr class="double">');
    }

    // Footer
    if (receiptFooter != null && receiptFooter.isNotEmpty) {
      buf.writeln('<p class="center bold">${_esc(receiptFooter)}</p>');
    } else {
      buf.writeln('<p class="center bold">Thank you!</p>');
      buf.writeln('<p class="center">Please come again</p>');
    }
    buf.writeln('</div>');
    buf.writeln('<script>window.onload = function() { window.print(); }</script>');
    buf.writeln('</body></html>');

    return buf.toString();
  }

  /// Generate session report HTML for browser print
  static String generateSessionReportHtml({
    required SessionReport report,
    required String storeName,
    required String storeAddress,
  }) {
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html><html><head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln('<title>Session Report</title>');
    buf.writeln('<style>');
    buf.writeln(_receiptCss);
    buf.writeln('</style></head><body>');

    buf.writeln('<div class="receipt">');
    buf.writeln('<h1>${_esc(storeName.toUpperCase())}</h1>');
    if (storeAddress.isNotEmpty) {
      buf.writeln('<p class="center">${_esc(storeAddress)}</p>');
    }
    buf.writeln('<hr class="double">');
    buf.writeln('<h2>LAPORAN SESSION</h2>');
    buf.writeln('<hr class="double">');

    // Session info
    buf.writeln('<p>Kasir: ${_esc(report.cashierName)}</p>');
    buf.writeln('<p>Buka: ${Formatters.dateTime(report.openedAt)}</p>');
    if (report.closedAt != null) {
      buf.writeln('<p>Tutup: ${Formatters.dateTime(report.closedAt!)}</p>');
    }
    final hours = report.duration.inHours;
    final minutes = report.duration.inMinutes % 60;
    buf.writeln('<p>Durasi: ${hours > 0 ? "${hours}j ${minutes}m" : "${minutes}m"}</p>');
    buf.writeln('<hr>');

    // Sales summary
    buf.writeln('<p class="bold">RINGKASAN PENJUALAN</p>');
    buf.writeln('<table class="totals">');
    buf.writeln('<tr><td>Total Order</td><td class="right">${report.totalOrders}</td></tr>');
    buf.writeln('<tr><td>Subtotal</td><td class="right">${Formatters.currencyCompact(report.totalSubtotal)}</td></tr>');
    if (report.totalDiscounts > 0) {
      buf.writeln('<tr><td>Diskon</td><td class="right">-${Formatters.currencyCompact(report.totalDiscounts)}</td></tr>');
    }
    buf.writeln('</table>');
    buf.writeln('<hr>');
    buf.writeln('<div class="total-row"><span>TOTAL</span><span>${Formatters.currency(report.totalSales)}</span></div>');
    buf.writeln('<hr class="double">');

    // Payment breakdown
    buf.writeln('<p class="bold">RINCIAN PEMBAYARAN</p>');
    buf.writeln('<table>');
    buf.writeln('<tr><th class="left">Metode</th><th>Jml</th><th class="right">Total</th></tr>');
    for (final b in report.allBreakdowns) {
      buf.writeln('<tr><td>${_esc(b.method)}</td><td class="center">${b.count}</td><td class="right">${Formatters.currencyCompact(b.totalAmount - b.totalChange)}</td></tr>');
    }
    buf.writeln('</table>');
    buf.writeln('<hr class="double">');

    // Cash reconciliation
    buf.writeln('<p class="bold">REKONSILIASI KAS</p>');
    buf.writeln('<table class="totals">');
    buf.writeln('<tr><td>Saldo Awal</td><td class="right">${Formatters.currencyCompact(report.openingCash)}</td></tr>');
    buf.writeln('<tr><td>Kas Masuk</td><td class="right">+${Formatters.currencyCompact(report.cashReceived)}</td></tr>');
    buf.writeln('<tr><td>Kembalian</td><td class="right">-${Formatters.currencyCompact(report.cashChangeGiven)}</td></tr>');
    buf.writeln('</table>');
    buf.writeln('<hr>');
    buf.writeln('<div class="total-row"><span>Diharapkan</span><span>${Formatters.currency(report.expectedClosingCash)}</span></div>');

    if (report.actualClosingCash != null) {
      buf.writeln('<table class="totals">');
      buf.writeln('<tr><td>Kas Aktual</td><td class="right">${Formatters.currency(report.actualClosingCash!)}</td></tr>');
      final diff = report.difference ?? 0;
      buf.writeln('<tr class="bold"><td>Selisih</td><td class="right">${diff == 0 ? "Seimbang" : "${diff > 0 ? "+" : ""}${Formatters.currency(diff)}"}</td></tr>');
      buf.writeln('</table>');
    }
    buf.writeln('<hr class="double">');

    buf.writeln('<p class="center bold">Session Report</p>');
    buf.writeln('<p class="center">${Formatters.dateTime(DateTime.now())}</p>');
    buf.writeln('</div>');
    buf.writeln('<script>window.onload = function() { window.print(); }</script>');
    buf.writeln('</body></html>');

    return buf.toString();
  }

  static String _esc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static const _receiptCss = '''
    @page { size: 80mm auto; margin: 0; }
    body { margin: 0; padding: 8px; font-family: 'Courier New', monospace; font-size: 12px; }
    .receipt { max-width: 300px; margin: 0 auto; }
    h1 { text-align: center; font-size: 16px; margin: 4px 0; }
    h2 { text-align: center; font-size: 14px; margin: 4px 0; }
    p { margin: 2px 0; }
    .center { text-align: center; }
    .right { text-align: right; }
    .left { text-align: left; }
    .bold { font-weight: bold; }
    hr { border: none; border-top: 1px dashed #000; margin: 4px 0; }
    hr.double { border-top: 2px solid #000; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 1px 2px; font-size: 11px; }
    .sub-item { padding-left: 12px; font-size: 10px; color: #555; }
    .total-row { display: flex; justify-content: space-between; font-size: 16px; font-weight: bold; padding: 4px 0; }
    .totals td { padding: 1px 2px; }
    @media print { body { padding: 0; } }
  ''';
}
