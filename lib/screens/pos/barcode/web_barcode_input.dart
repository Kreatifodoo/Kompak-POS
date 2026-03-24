import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../models/cart_item_model.dart';
import '../../../modules/product/product_providers.dart';
import '../../../modules/pos/cart_providers.dart';

/// Web fallback for barcode scanning — manual text input.
/// Used when camera-based scanning is not available (web browser).
class WebBarcodeInput extends ConsumerStatefulWidget {
  const WebBarcodeInput({super.key});

  @override
  ConsumerState<WebBarcodeInput> createState() => _WebBarcodeInputState();
}

class _WebBarcodeInputState extends ConsumerState<WebBarcodeInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Input Barcode', style: AppTextStyles.heading3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.infoBlue, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Masukkan nomor barcode produk atau gunakan barcode scanner USB/wireless',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.infoBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Barcode input field
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookupBarcode(),
              decoration: InputDecoration(
                hintText: 'Ketik atau scan barcode...',
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded,
                    color: AppColors.primaryOrange),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded,
                      color: AppColors.primaryOrange),
                  onPressed: _isProcessing ? null : _lookupBarcode,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryOrange, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surfaceGrey,
              ),
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),

            // Search button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _lookupBarcode,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.white),
                label: Text(
                  _isProcessing ? 'Mencari...' : 'Cari & Tambah ke Keranjang',
                  style: AppTextStyles.buttonText,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  disabledBackgroundColor: AppColors.borderGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Illustration
            Icon(
              Icons.qr_code_2_rounded,
              size: 120,
              color: AppColors.textHint.withOpacity(0.2),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Scan barcode menggunakan scanner USB\natau ketik nomor barcode manual',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lookupBarcode() async {
    final barcode = _controller.text.trim();
    if (barcode.isEmpty) {
      context.showSnackBar('Masukkan nomor barcode', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final product =
          await ref.read(productByBarcodeProvider(barcode).future);

      if (!mounted) return;

      if (product != null) {
        final cartItem = CartItem(
          productId: product.id,
          productName: product.name,
          productPrice: product.price,
          quantity: 1,
          lineTotal: product.price,
          imageUrl: product.imageUrl,
        );
        ref.read(cartProvider.notifier).addItem(cartItem);
        context.showSnackBar('${product.name} ditambahkan ke keranjang');
        context.pop();
      } else {
        context.showSnackBar(
            'Produk tidak ditemukan untuk barcode: $barcode',
            isError: true);
        _controller.clear();
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
