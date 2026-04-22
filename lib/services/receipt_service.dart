import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
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

// ════════════════════════════════════════════════════════════════
//  TYPOGRAPHY SYSTEM for 58mm thermal receipt (no bold anywhere)
//
//  58mm fontA ≈ 32 chars/line,  fontB ≈ 42 chars/line
//
//  TYPE 3 — HEADER : fontA + height×2  (nama toko, TOTAL)
//  TYPE 1 — BODY   : fontA + size1     (item lines, subtotal, payment)
//  TYPE 2 — DETAIL : fontB             (harga satuan, combo, notes, promo, charges)
//  TYPE 4 — FOOTER : fontB + center    (terima kasih, hemat, meta)
// ════════════════════════════════════════════════════════════════

// Type 3 — Header (larger, centered)
const _t3Center = PosStyles(align: PosAlign.center, height: PosTextSize.size2);

// Type 1 — Body (standard fontA)
const _t1 = PosStyles();
const _t1Center = PosStyles(align: PosAlign.center);
const _t1Right = PosStyles(align: PosAlign.right);

// Type 2 — Detail (condensed fontB, fits ~42 chars → no truncation)
const _t2 = PosStyles(fontType: PosFontType.fontB);
const _t2Right = PosStyles(fontType: PosFontType.fontB, align: PosAlign.right);
const _t2Center = PosStyles(fontType: PosFontType.fontB, align: PosAlign.center);

// Type 4 — Footer (condensed fontB, centered)
const _t4 = PosStyles(fontType: PosFontType.fontB, align: PosAlign.center);

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
    String? terminalName,
    String? branchName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // ── LOGO ────────────────────────────────────────────────
    if (!kIsWeb && logoPath != null && logoPath.isNotEmpty) {
      try {
        final logoBytes = await file_helper.readFileBytes(logoPath);
        if (logoBytes != null) {
          final original = img.decodeImage(logoBytes);
          if (original != null) {
            // Force square 120x120 logo
            final resized = img.copyResize(original, width: 120, height: 120);
            bytes += generator.imageRaster(resized, align: PosAlign.center);
            // Spacing between logo and store name — 6 lines gap
            bytes += generator.feed(6);
          }
        }
      } catch (_) {}
    }

    // ── HEADER (Type 3) ─────────────────────────────────────
    bytes += generator.text(storeName.toUpperCase(), styles: _t3Center);
    bytes += generator.feed(1); // spacing after store name

    // Address & custom header (Type 2 — smaller, won't clip long address)
    if (storeAddress.isNotEmpty) {
      bytes += generator.text(storeAddress, styles: _t2Center);
    }
    if (receiptHeader != null && receiptHeader.isNotEmpty) {
      bytes += generator.text(receiptHeader, styles: _t2Center);
    }
    bytes += generator.hr(ch: '=');

    // ── ORDER INFO (Type 2 — detail size) ───────────────────
    bytes += generator.text('Order : ${order.orderNumber}', styles: _t2);
    bytes += generator.text('Date  : ${Formatters.dateTime(order.createdAt)}', styles: _t2);
    bytes += generator.text('Kasir : $cashierName', styles: _t2);
    if (terminalName != null && terminalName.isNotEmpty) {
      bytes += generator.text('Term. : $terminalName', styles: _t2);
    }
    if (branchName != null && branchName.isNotEmpty) {
      bytes += generator.text('Cabang: $branchName', styles: _t2);
    }
    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Cust. : $customerName', styles: _t2);
    }
    bytes += generator.hr();

    // ── COLUMN HEADER (Type 1 — body) ───────────────────────
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: _t1),
      PosColumn(text: 'Qty', width: 2, styles: _t1Center),
      PosColumn(text: 'Amount', width: 4, styles: _t1Right),
    ]);
    bytes += generator.hr();

    // ── ITEMS (Type 1 for main line, Type 2 for details) ────
    for (final item in items) {
      // Main item line — Type 1
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6, styles: _t1),
        PosColumn(text: '${item.quantity}', width: 2, styles: _t1Center),
        PosColumn(text: Formatters.currencyCompact(item.subtotal), width: 4, styles: _t1Right),
      ]);

      // Per-unit price — Type 2 (smaller, won't clip)
      if (item.quantity > 1 ||
          (item.originalPrice != null && item.originalPrice! > item.productPrice)) {
        bytes += generator.text(
          '  @${Formatters.currencyCompact(item.productPrice)}/pcs',
          styles: _t2,
        );
      }

      // Combo selections — Type 2
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
              bytes += generator.text('  * ${sel.productName}$extraLabel', styles: _t2);
            }
          }
        } catch (_) {}
      }

      // Item notes — Type 2
      if (item.notes != null && item.notes!.isNotEmpty) {
        for (final line in item.notes!.split('\n')) {
          if (line.trim().isNotEmpty) {
            bytes += generator.text('  >> $line', styles: _t2);
          }
        }
      }

      // Per-item savings — Type 2
      if (item.originalPrice != null && item.originalPrice! > item.productPrice) {
        final savings = (item.originalPrice! - item.productPrice) * item.quantity;
        bytes += generator.text('  Hemat: ${Formatters.currencyCompact(savings)}', styles: _t2);
      }
    }

    bytes += generator.hr();

    // ── SUBTOTAL SECTION (Type 2 — all detail lines) ────────
    // Using fontB row for promo/charges to fit long labels (~42 chars)
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6, styles: _t2),
      PosColumn(text: Formatters.currencyCompact(order.subtotal), width: 6, styles: _t2Right),
    ]);

    if (order.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6, styles: _t2),
        PosColumn(text: '-${Formatters.currencyCompact(order.discountAmount)}', width: 6, styles: _t2Right),
      ]);
    }

    // Promotions — Type 2 (long promo names now fit in fontB)
    if (order.promotionsJson != null && order.promotionsJson!.isNotEmpty) {
      final promoList = (jsonDecode(order.promotionsJson!) as List)
          .map((e) => AppliedPromotion.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final promo in promoList) {
        final label = promo.tipeReward == PromotionTipeReward.diskonPersentase
            ? '${promo.namaPromo} ${promo.nilaiReward.toStringAsFixed(promo.nilaiReward.truncateToDouble() == promo.nilaiReward ? 0 : 1)}%'
            : promo.namaPromo;
        bytes += generator.row([
          PosColumn(text: label, width: 7, styles: _t2),
          PosColumn(text: '-${Formatters.currencyCompact(promo.discountAmount)}', width: 5, styles: _t2Right),
        ]);
      }
    }

    // Charges (tax, service, etc.) — Type 2
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
          PosColumn(text: label, width: 7, styles: _t2),
          PosColumn(text: '$prefix${Formatters.currencyCompact(charge.amount.abs())}', width: 5, styles: _t2Right),
        ]);
      }
    } else if (order.taxAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 6, styles: _t2),
        PosColumn(text: Formatters.currencyCompact(order.taxAmount), width: 6, styles: _t2Right),
      ]);
    }

    bytes += generator.hr(ch: '=');

    // ── TOTAL (Type 3 — header size) ────────────────────────
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 5, styles: const PosStyles(height: PosTextSize.size2)),
      PosColumn(
        text: Formatters.currency(order.total),
        width: 7,
        styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.hr(ch: '=');

    // ── PAYMENT INFO (Type 1 — body) ────────────────────────
    bytes += generator.text('Payment : ${payment.method.toUpperCase()}', styles: _t1);
    if (payment.method == 'cash') {
      bytes += generator.text('Tendered: ${Formatters.currency(payment.amount)}', styles: _t1);
      bytes += generator.text('Change  : ${Formatters.currency(payment.changeAmount)}', styles: _t1);
    }

    bytes += generator.feed(1);

    // ── FOOTER (Type 4) ─────────────────────────────────────
    bytes += generator.hr(ch: '-');
    if (receiptFooter != null && receiptFooter.isNotEmpty) {
      bytes += generator.text(receiptFooter, styles: _t4);
    } else {
      bytes += generator.text('Terima kasih!', styles: _t4);
      bytes += generator.text('Silakan berkunjung kembali', styles: _t4);
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // ════════════════════════════════════════════════════════════
  //  SESSION REPORT (same typography system)
  // ════════════════════════════════════════════════════════════

  Future<List<int>> generateSessionReport({
    required SessionReport report,
    required String storeName,
    required String storeAddress,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // ── HEADER (Type 3) ─────────────────────────────────────
    bytes += generator.text(storeName.toUpperCase(), styles: _t3Center);
    bytes += generator.feed(1);
    if (storeAddress.isNotEmpty) {
      bytes += generator.text(storeAddress, styles: _t2Center);
    }
    bytes += generator.hr(ch: '=');

    bytes += generator.text('LAPORAN SESSION', styles: _t3Center);
    bytes += generator.hr(ch: '=');

    // ── SESSION INFO (Type 2 — detail) ──────────────────────
    bytes += generator.text('Kasir : ${report.cashierName}', styles: _t2);
    bytes += generator.text('Buka  : ${Formatters.dateTime(report.openedAt)}', styles: _t2);
    if (report.closedAt != null) {
      bytes += generator.text('Tutup : ${Formatters.dateTime(report.closedAt!)}', styles: _t2);
    }
    final hours = report.duration.inHours;
    final minutes = report.duration.inMinutes % 60;
    bytes += generator.text(
      'Durasi: ${hours > 0 ? "${hours}j ${minutes}m" : "${minutes}m"}',
      styles: _t2,
    );
    bytes += generator.hr();

    // ── SALES SUMMARY (Type 1 — body) ───────────────────────
    bytes += generator.text('RINGKASAN PENJUALAN', styles: _t1Center);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Total Order', width: 6, styles: _t1),
      PosColumn(text: '${report.totalOrders}', width: 6, styles: _t1Right),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6, styles: _t1),
      PosColumn(text: Formatters.currencyCompact(report.totalSubtotal), width: 6, styles: _t1Right),
    ]);
    if (report.totalDiscounts > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon', width: 6, styles: _t1),
        PosColumn(text: '-${Formatters.currencyCompact(report.totalDiscounts)}', width: 6, styles: _t1Right),
      ]);
    }
    bytes += generator.hr();
    // TOTAL — Type 3
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 5, styles: const PosStyles(height: PosTextSize.size2)),
      PosColumn(
        text: Formatters.currency(report.totalSales),
        width: 7,
        styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]);
    bytes += generator.hr(ch: '=');

    // ── PAYMENT BREAKDOWN (Type 1) ──────────────────────────
    bytes += generator.text('RINCIAN PEMBAYARAN', styles: _t1Center);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Metode', width: 4, styles: _t1),
      PosColumn(text: 'Jml', width: 2, styles: _t1Center),
      PosColumn(text: 'Total', width: 6, styles: _t1Right),
    ]);
    bytes += generator.hr();
    for (final b in report.allBreakdowns) {
      bytes += generator.row([
        PosColumn(text: b.method, width: 4, styles: _t1),
        PosColumn(text: '${b.count}', width: 2, styles: _t1Center),
        PosColumn(text: Formatters.currencyCompact(b.totalAmount - b.totalChange), width: 6, styles: _t1Right),
      ]);
    }
    bytes += generator.hr(ch: '=');

    // ── CASH RECONCILIATION (Type 1) ────────────────────────
    bytes += generator.text('REKONSILIASI KAS', styles: _t1Center);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Saldo Awal', width: 6, styles: _t1),
      PosColumn(text: Formatters.currencyCompact(report.openingCash), width: 6, styles: _t1Right),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kas Masuk', width: 6, styles: _t1),
      PosColumn(text: '+${Formatters.currencyCompact(report.cashReceived)}', width: 6, styles: _t1Right),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kembalian', width: 6, styles: _t1),
      PosColumn(text: '-${Formatters.currencyCompact(report.cashChangeGiven)}', width: 6, styles: _t1Right),
    ]);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Diharapkan', width: 6, styles: _t1),
      PosColumn(text: Formatters.currency(report.expectedClosingCash), width: 6, styles: _t1Right),
    ]);
    if (report.actualClosingCash != null) {
      bytes += generator.row([
        PosColumn(text: 'Kas Aktual', width: 6, styles: _t1),
        PosColumn(text: Formatters.currency(report.actualClosingCash!), width: 6, styles: _t1Right),
      ]);
      final diff = report.difference ?? 0;
      bytes += generator.row([
        PosColumn(text: 'Selisih', width: 6, styles: _t1),
        PosColumn(
          text: diff == 0
              ? 'Seimbang'
              : '${diff > 0 ? "+" : ""}${Formatters.currency(diff)}',
          width: 6,
          styles: _t1Right,
        ),
      ]);
    }
    bytes += generator.hr(ch: '=');

    // ── FOOTER (Type 4) ─────────────────────────────────────
    bytes += generator.text('Session Report', styles: _t4);
    bytes += generator.text(Formatters.dateTime(DateTime.now()), styles: _t4);

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }
}
