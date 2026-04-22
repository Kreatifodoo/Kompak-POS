import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/printer/printer_providers.dart';
import '../../modules/core_providers.dart';
import '../../services/barcode_label_service.dart';

class BarcodeLabelScreen extends ConsumerStatefulWidget {
  final Product product;

  const BarcodeLabelScreen({super.key, required this.product});

  @override
  ConsumerState<BarcodeLabelScreen> createState() => _BarcodeLabelScreenState();
}

class _BarcodeLabelScreenState extends ConsumerState<BarcodeLabelScreen> {
  int _qty = 1;
  bool _isPrinting = false;

  Product get product => widget.product;

  String get _barcodeValue => BarcodeLabelService.barcodeValueFor(product);

  Future<void> _print() async {
    if (kIsWeb) {
      context.showSnackBar('Print label hanya tersedia di APK Android', isError: true);
      return;
    }

    final printerService = ref.read(printerServiceProvider);
    final isConnected = await printerService.checkConnection();
    if (!isConnected) {
      if (!mounted) return;
      context.showSnackBar('Printer belum terhubung. Buka Settings → Printer Settings.', isError: true);
      return;
    }

    setState(() => _isPrinting = true);
    try {
      final storeName = ref.read(currentStoreProvider)?.name ?? 'Kompak POS';
      final bytes = await BarcodeLabelService.generateLabel(
        product: product,
        storeName: storeName,
        qty: _qty,
      );
      final success = await printerService.printReceipt(bytes);
      if (mounted) {
        if (success) {
          context.showSnackBar('$_qty label berhasil dicetak');
        } else {
          context.showSnackBar('Gagal mencetak label', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(printerConnectedProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Print Barcode Label', style: AppTextStyles.heading3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Printer status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.successGreen.withOpacity(0.08)
                    : AppColors.warningAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConnected
                      ? AppColors.successGreen.withOpacity(0.3)
                      : AppColors.warningAmber.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.print_rounded
                        : Icons.print_disabled_rounded,
                    color: isConnected
                        ? AppColors.successGreen
                        : AppColors.warningAmber,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isConnected
                          ? 'Printer terhubung — siap cetak'
                          : 'Printer belum terhubung — hubungkan di Settings → Printer',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isConnected
                            ? AppColors.successGreen
                            : AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!isConnected)
                    TextButton(
                      onPressed: () => context.push('/settings/printer'),
                      child: Text(
                        'Connect',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warningAmber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Label Preview ────────────────────────────────────────────────
            Text('Preview Label', style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),

            Center(
              child: _LabelPreview(
                product: product,
                barcodeValue: _barcodeValue,
                storeName: ref.watch(currentStoreProvider)?.name ?? 'Kompak POS',
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Barcode value info ────────────────────────────────────────────
            if (product.barcode == null || product.barcode!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.infoBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.infoBlue, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        product.sku != null && product.sku!.isNotEmpty
                            ? 'Barcode belum diisi — menggunakan SKU: ${product.sku}'
                            : 'Barcode & SKU belum diisi — menggunakan ID produk. Disarankan mengisi barcode di form produk.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.infoBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.lg),

            // ── Qty selector ─────────────────────────────────────────────────
            Text('Jumlah Label', style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGrey),
                  ),
                  child: Text(
                    '$_qty',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading3,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _QtyButton(
                  icon: Icons.add_rounded,
                  onPressed: _qty < 50 ? () => setState(() => _qty++) : null,
                ),
                const SizedBox(width: AppSpacing.md),
                // Quick-select buttons
                for (final n in [5, 10, 20])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _qty = n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _qty == n
                              ? AppColors.primaryOrange.withOpacity(0.12)
                              : AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _qty == n
                                ? AppColors.primaryOrange
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '$n',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _qty == n
                                ? AppColors.primaryOrange
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Print button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _print,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.print_rounded, color: Colors.white),
                label: Text(
                  _isPrinting
                      ? 'Mencetak...'
                      : 'Cetak $_qty Label',
                  style: AppTextStyles.buttonText,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Tip
            Text(
              'Tip: Barcode yang dicetak adalah format CODE128 — dapat dipindai oleh scanner kamera maupun Bluetooth.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Label Preview Widget ─────────────────────────────────────────────────────

class _LabelPreview extends StatelessWidget {
  final Product product;
  final String barcodeValue;
  final String storeName;

  const _LabelPreview({
    required this.product,
    required this.barcodeValue,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Store name
          Text(
            storeName,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Product name
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Price
          Text(
            Formatters.currency(product.price),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Visual barcode simulation (actual bars rendered as thin rects)
          _BarcodeVisual(value: barcodeValue),

          const SizedBox(height: 2),

          // Barcode value text
          Text(
            barcodeValue,
            style: const TextStyle(
              fontSize: 8,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),

          // SKU
          if (product.sku != null && product.sku!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'SKU: ${product.sku}',
              style: const TextStyle(fontSize: 8, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300, height: 1),
        ],
      ),
    );
  }
}

/// Renders a visual barcode approximation using thin vertical rectangles.
/// This is a UI preview only — the real barcode is generated by the printer.
class _BarcodeVisual extends StatelessWidget {
  final String value;

  const _BarcodeVisual({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 48,
      child: CustomPaint(
        painter: _BarcodePainter(value),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String value;

  _BarcodePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Generate a deterministic bar pattern from the value string
    // (visual approximation — not a real Code128 calculation)
    final seed = _generatePattern(value);
    final totalModules = seed.length;
    if (totalModules == 0) return;

    final moduleWidth = size.width / totalModules;

    for (int i = 0; i < totalModules; i++) {
      if (seed[i]) {
        canvas.drawRect(
          Rect.fromLTWH(
            i * moduleWidth,
            0,
            moduleWidth.clamp(0.8, 4.0),
            size.height,
          ),
          paint,
        );
      }
    }
  }

  /// Generates a visual bar pattern from the value (deterministic, not real Code128).
  List<bool> _generatePattern(String value) {
    // Quiet zone (5 modules) + start + data + stop + quiet zone
    final pattern = <bool>[];

    // Quiet zone
    for (int i = 0; i < 5; i++) pattern.add(false);

    // Start pattern (Code128 start char)
    final startBars = [true, true, false, true, false, false, true, true, false, false];
    pattern.addAll(startBars);

    // Data: encode each char as a pseudo-barcode based on ASCII value
    for (int ci = 0; ci < value.length && ci < 16; ci++) {
      final code = value.codeUnitAt(ci);
      // Generate 11 bars per character (Code128 uses 11 modules per char)
      for (int b = 0; b < 11; b++) {
        final bit = (code >> (b % 7)) & 1;
        pattern.add(b % 3 == 0 ? true : bit == 1);
      }
    }

    // Stop pattern
    final stopBars = [true, true, false, false, false, true, false, false, false, true, true, false];
    pattern.addAll(stopBars);

    // Quiet zone
    for (int i = 0; i < 5; i++) pattern.add(false);

    return pattern;
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.value != value;
}

// ── Qty Button helper ────────────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onPressed != null ? AppColors.primaryOrange : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: onPressed != null ? Colors.white : AppColors.textHint,
          size: 20,
        ),
      ),
    );
  }
}
