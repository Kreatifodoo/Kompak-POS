import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import '../core/database/app_database.dart';
import '../core/utils/formatters.dart';

/// Generates ESC/POS bytes for a product barcode label.
/// Uses the printer's native CODE128 command — printer renders real bars.
class BarcodeLabelService {
  /// The barcode value to print: prefers product.barcode, then SKU,
  /// then falls back to an 8-char product ID prefix.
  static String barcodeValueFor(Product product) {
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      return product.barcode!;
    }
    if (product.sku != null && product.sku!.isNotEmpty) {
      return product.sku!;
    }
    return product.id.substring(0, 8).toUpperCase();
  }

  /// Returns whether [product] has a printable barcode.
  static bool hasPrintableBarcode(Product product) => true; // always fallback

  /// Generate ESC/POS bytes for [qty] copies of the product label.
  static Future<List<int>> generateLabel({
    required Product product,
    required String storeName,
    int qty = 1,
  }) async {
    if (kIsWeb) return []; // Web uses browser print
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];
    bytes += generator.reset();

    for (int i = 0; i < qty; i++) {
      bytes += _buildLabel(generator, product, storeName);
      if (i < qty - 1) bytes += generator.feed(1); // gap between labels
    }
    bytes += generator.feed(3);
    bytes += generator.cut();
    return bytes;
  }

  static List<int> _buildLabel(
    Generator g,
    Product product,
    String storeName,
  ) {
    List<int> bytes = [];
    final value = barcodeValueFor(product);

    // ── Store name ──────────────────────────────────────────────────────────
    bytes += g.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontB,
      ),
    );

    // ── Product name (bold, wrap if long) ───────────────────────────────────
    // 58mm printer ≈ 32 chars wide at normal font
    final nameLines = _wrapText(product.name, 24);
    for (final line in nameLines) {
      bytes += g.text(
        line,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
    }

    // ── Price ────────────────────────────────────────────────────────────────
    bytes += g.text(
      Formatters.currency(product.price),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += g.feed(1);

    // ── CODE128 barcode (native ESC/POS — printer renders real bars) ─────────
    try {
      // Code128 subset B: {B prefix supports full alphanumeric
      final barcodeData = '{B$value'.split('');
      bytes += g.barcode(
        Barcode.code128(barcodeData),
        height: 80,
        textPos: BarcodeText.below,
        font: BarcodeFont.fontB,
      );
    } catch (_) {
      // Fallback: print value as text only
      bytes += g.text(
        value,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    // ── SKU line ─────────────────────────────────────────────────────────────
    if (product.sku != null && product.sku!.isNotEmpty) {
      bytes += g.text(
        'SKU: ${product.sku}',
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontB,
        ),
      );
    }

    bytes += g.hr(ch: '-');
    return bytes;
  }

  /// Split [text] into lines of at most [maxLen] chars (word-aware).
  static List<String> _wrapText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= maxLen) {
        current += ' $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [text.substring(0, maxLen)] : lines;
  }
}
