import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
// flutter_esc_pos_utils is pure Dart (no dart:io/ffi) — safe on web
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart' as img;

import '../core/utils/file_helper.dart' as file_helper;
import '../core/database/app_database.dart';
import '../core/utils/formatters.dart';
import '../models/applied_charge_model.dart';
import '../models/applied_promotion_model.dart';
import '../models/cart_item_model.dart';
import '../models/enums.dart';
import '../models/session_report_model.dart';

class ReceiptService {
  Future<List<int>> generateReceipt({
    required String storeName,
    required String storeAddress,
    required String cashierName,
    required Order order,
    required List<OrderItem> items,
    required Payment payment,
    String? logoPath,
    String? customerName,
    String? receiptHeader,
    String? receiptFooter,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // IMPORTANT: Initialize/reset the printer first
    bytes += generator.reset();

    // Logo (if available — mobile only, skip on web)
    if (!kIsWeb && logoPath != null && logoPath.isNotEmpty) {
      try {
        final logoBytes = await file_helper.readFileBytes(logoPath);
        if (logoBytes != null) {
          final original = img.decodeImage(logoBytes);
          if (original != null) {
            // Resize to 200px wide (good for 58mm paper)
            final resized = img.copyResize(original, width: 200);
            bytes += generator.imageRaster(resized, align: PosAlign.center);
            bytes += generator.feed(1);
          }
        }
      } catch (_) {
        // Skip logo on error — fall back to text header
      }
    }

    // Header
    bytes += generator.text(
      storeName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (storeAddress.isNotEmpty) {
      bytes += generator.text(
        storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (receiptHeader != null && receiptHeader.isNotEmpty) {
      bytes += generator.text(
        receiptHeader,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr(ch: '=');

    // Order info
    bytes += generator.text('Order: ${order.orderNumber}');
    bytes += generator.text('Date: ${Formatters.dateTime(order.createdAt)}');
    bytes += generator.text('Cashier: $cashierName');
    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Customer: $customerName');
    }
    bytes += generator.hr();

    // Column header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: 'Amount', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.hr();

    // Items
    for (final item in items) {
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6),
        PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
          text: Formatters.currencyCompact(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      // Print combo selections if present
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
              bytes += generator.text(
                '   * ${sel.productName}$extraLabel',
                styles: const PosStyles(
                  align: PosAlign.left,
                  fontType: PosFontType.fontB,
                ),
              );
            }
          }
        } catch (_) {}
      }
      // Print item notes if present (each line indented with >>)
      if (item.notes != null && item.notes!.isNotEmpty) {
        final noteLines = item.notes!.split('\n');
        for (final line in noteLines) {
          if (line.trim().isNotEmpty) {
            bytes += generator.text(
              '   >> $line',
              styles: const PosStyles(
                align: PosAlign.left,
                fontType: PosFontType.fontB,
              ),
            );
          }
        }
      }
      // Print per-item savings if pricelist applied
      if (item.originalPrice != null &&
          item.originalPrice! > item.productPrice) {
        final itemSavings =
            (item.originalPrice! - item.productPrice) * item.quantity;
        bytes += generator.text(
          '   Hemat: ${Formatters.currencyCompact(itemSavings)}',
          styles: const PosStyles(
            align: PosAlign.left,
            fontType: PosFontType.fontB,
          ),
        );
      }
    }

    bytes += generator.hr();

    // Totals
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
        text: Formatters.currencyCompact(order.subtotal),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (order.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(
          text: '-${Formatters.currencyCompact(order.discountAmount)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Promotions breakdown
    if (order.promotionsJson != null && order.promotionsJson!.isNotEmpty) {
      final promoList = (jsonDecode(order.promotionsJson!) as List)
          .map((e) => AppliedPromotion.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final promo in promoList) {
        final label = promo.tipeReward == PromotionTipeReward.diskonPersentase
            ? '${promo.namaPromo} ${promo.nilaiReward.toStringAsFixed(promo.nilaiReward.truncateToDouble() == promo.nilaiReward ? 0 : 1)}%'
            : promo.namaPromo;
        bytes += generator.row([
          PosColumn(text: label, width: 6),
          PosColumn(
            text: '-${Formatters.currencyCompact(promo.discountAmount)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    }

    // Dynamic charges breakdown
    if (order.chargesJson != null && order.chargesJson!.isNotEmpty) {
      final chargesList = (jsonDecode(order.chargesJson!) as List)
          .map((e) => AppliedCharge.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final charge in chargesList) {
        final label = charge.tipe == ChargeTipe.persentase
            ? '${charge.namaBiaya} ${charge.nilai.toStringAsFixed(charge.nilai.truncateToDouble() == charge.nilai ? 0 : 1)}%'
            : charge.namaBiaya;
        final prefix = charge.isDeduction ? '-' : '';
        bytes += generator.row([
          PosColumn(text: label, width: 6),
          PosColumn(
            text: '$prefix${Formatters.currencyCompact(charge.amount.abs())}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    } else if (order.taxAmount > 0) {
      // Fallback for legacy orders
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 6),
        PosColumn(
          text: Formatters.currencyCompact(order.taxAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr(ch: '=');

    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: Formatters.currency(order.total),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]);

    bytes += generator.hr(ch: '=');

    // Payment info
    bytes += generator.text('Payment: ${payment.method.toUpperCase()}');
    if (payment.method == 'cash') {
      bytes += generator.text(
          'Tendered: ${Formatters.currency(payment.amount)}');
      bytes += generator.text(
          'Change: ${Formatters.currency(payment.changeAmount)}');
    }

    bytes += generator.hr(ch: '=');

    // Savings info — pricelist savings + promotion discounts
    double totalSavings = items.fold<double>(0, (sum, item) {
      if (item.originalPrice != null &&
          item.originalPrice! > item.productPrice) {
        return sum +
            (item.originalPrice! - item.productPrice) * item.quantity;
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
      bytes += generator.text(
        'Anda hemat ${Formatters.currency(totalSavings)}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.hr(ch: '=');
    }

    // Footer
    if (receiptFooter != null && receiptFooter.isNotEmpty) {
      bytes += generator.text(
        receiptFooter,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    } else {
      bytes += generator.text(
        'Thank you!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Please come again',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> generateSessionReport({
    required SessionReport report,
    required String storeName,
    required String storeAddress,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // Header
    bytes += generator.text(
      storeName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (storeAddress.isNotEmpty) {
      bytes += generator.text(
        storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr(ch: '=');

    bytes += generator.text(
      'LAPORAN SESSION',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );
    bytes += generator.hr(ch: '=');

    // Session info
    bytes += generator.text('Kasir: ${report.cashierName}');
    bytes += generator.text('Buka: ${Formatters.dateTime(report.openedAt)}');
    if (report.closedAt != null) {
      bytes += generator.text('Tutup: ${Formatters.dateTime(report.closedAt!)}');
    }
    final hours = report.duration.inHours;
    final minutes = report.duration.inMinutes % 60;
    bytes += generator.text(
        'Durasi: ${hours > 0 ? "${hours}j ${minutes}m" : "${minutes}m"}');
    bytes += generator.hr();

    // Sales summary
    bytes += generator.text('RINGKASAN PENJUALAN',
        styles: const PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(text: 'Total Order', width: 6),
      PosColumn(
          text: '${report.totalOrders}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
          text: Formatters.currencyCompact(report.totalSubtotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (report.totalDiscounts > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon', width: 6),
        PosColumn(
            text: '-${Formatters.currencyCompact(report.totalDiscounts)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: Formatters.currency(report.totalSales),
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size2)),
    ]);
    bytes += generator.hr(ch: '=');

    // Payment breakdown
    bytes += generator.text('RINCIAN PEMBAYARAN',
        styles: const PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(
          text: 'Metode',
          width: 4,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Jml',
          width: 2,
          styles: const PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(
          text: 'Total',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.hr();
    for (final b in report.allBreakdowns) {
      bytes += generator.row([
        PosColumn(text: b.method, width: 4),
        PosColumn(
            text: '${b.count}',
            width: 2,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: Formatters.currencyCompact(b.totalAmount - b.totalChange),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr(ch: '=');

    // Cash reconciliation
    bytes += generator.text('REKONSILIASI KAS',
        styles: const PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(text: 'Saldo Awal', width: 6),
      PosColumn(
          text: Formatters.currencyCompact(report.openingCash),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kas Masuk', width: 6),
      PosColumn(
          text: '+${Formatters.currencyCompact(report.cashReceived)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kembalian', width: 6),
      PosColumn(
          text: '-${Formatters.currencyCompact(report.cashChangeGiven)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
          text: 'Diharapkan',
          width: 6,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: Formatters.currency(report.expectedClosingCash),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    if (report.actualClosingCash != null) {
      bytes += generator.row([
        PosColumn(text: 'Kas Aktual', width: 6),
        PosColumn(
            text: Formatters.currency(report.actualClosingCash!),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      final diff = report.difference ?? 0;
      bytes += generator.row([
        PosColumn(
            text: 'Selisih',
            width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: diff == 0
                ? 'Seimbang'
                : '${diff > 0 ? "+" : ""}${Formatters.currency(diff)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }
    bytes += generator.hr(ch: '=');

    // Footer
    bytes += generator.text(
      'Session Report',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      Formatters.dateTime(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

}
