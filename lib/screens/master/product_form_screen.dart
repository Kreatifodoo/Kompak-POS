import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/file_helper.dart' as file_helper;
import '../../core/widgets/cross_platform_image.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/product/product_providers.dart';
import 'barcode_label_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _skuController;
  late final TextEditingController _discountController;

  String? _selectedCategoryId;
  List<Category> _categories = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isCombo = false;
  bool _hasBom = false;

  /// Local file path of the selected/existing image.
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _costPriceController = TextEditingController();
    _descriptionController = TextEditingController();
    _barcodeController = TextEditingController();
    _skuController = TextEditingController();
    _discountController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(productServiceProvider);
      final categories = await service.getCategories(storeId);

      setState(() {
        _categories = categories;
      });

      if (widget.isEditing) {
        final product = await service.getProductById(widget.productId!);
        if (product != null && mounted) {
          _nameController.text = product.name;
          _priceController.text = product.price.toStringAsFixed(0);
          _costPriceController.text =
              product.costPrice?.toStringAsFixed(0) ?? '';
          _descriptionController.text = product.description ?? '';
          _barcodeController.text = product.barcode ?? '';
          _skuController.text = product.sku ?? '';
          _discountController.text =
              product.discountPercent?.toStringAsFixed(0) ?? '';
          setState(() {
            _selectedCategoryId = product.categoryId;
            _imagePath = product.imageUrl;
            _isCombo = product.isCombo;
            _hasBom = product.hasBom;
          });
        }
      } else {
        if (categories.isNotEmpty) {
          setState(() {
            _selectedCategoryId = categories.first.id;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to load data', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      if (kIsWeb) {
        // On web, just use the picked path directly (browser handles it)
        setState(() => _imagePath = picked.path);
      } else {
        // Mobile: Copy to app documents dir so the image persists
        final appDir = await getApplicationDocumentsDirectory();
        final imgDirPath = '${appDir.path}/product_images';
        await file_helper.createDirectory(imgDirPath);

        final ext = p.extension(picked.path);
        final fileName =
            'product_${DateTime.now().millisecondsSinceEpoch}$ext';
        final destPath = '$imgDirPath/$fileName';
        final savedPath = await file_helper.copyFile(picked.path, destPath);

        if (savedPath != null) {
          setState(() => _imagePath = savedPath);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to pick image', isError: true);
      }
    }
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      context.showSnackBar('Please select a category', isError: true);
      return;
    }

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(productServiceProvider);
      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final costPrice = _costPriceController.text.trim().isNotEmpty
          ? double.tryParse(_costPriceController.text.trim())
          : null;
      final description = _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null;
      final barcode = _barcodeController.text.trim().isNotEmpty
          ? _barcodeController.text.trim()
          : null;
      final sku = _skuController.text.trim().isNotEmpty
          ? _skuController.text.trim()
          : null;
      final discount = _discountController.text.trim().isNotEmpty
          ? double.tryParse(_discountController.text.trim())
          : null;

      if (widget.isEditing) {
        await service.updateProduct(
          id: widget.productId!,
          storeId: storeId,
          categoryId: _selectedCategoryId!,
          name: name,
          price: price,
          costPrice: costPrice,
          description: description,
          barcode: barcode,
          sku: sku,
          discountPercent: discount,
          imageUrl: _imagePath,
          isCombo: _isCombo,
          hasBom: _hasBom,
        );
      } else {
        await service.createProduct(
          storeId: storeId,
          categoryId: _selectedCategoryId!,
          name: name,
          price: price,
          costPrice: costPrice,
          description: description,
          barcode: barcode,
          sku: sku,
          discountPercent: discount,
          imageUrl: _imagePath,
          isCombo: _isCombo,
          hasBom: _hasBom,
        );
      }

      ref.invalidate(allProductsProvider);
      ref.invalidate(filteredProductsProvider);

      if (mounted) {
        context.showSnackBar(
          widget.isEditing ? 'Product updated' : 'Product created',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save product', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openBarcodeLabelPrint() {
    if (!widget.isEditing) return;
    final db = ref.read(databaseProvider);
    db.productDao.getById(widget.productId!).then((product) {
      if (product != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BarcodeLabelScreen(product: product),
          ),
        );
      }
    });
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
            'Are you sure you want to delete "${_nameController.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(productServiceProvider);
      await service.deactivateProduct(widget.productId!);
      ref.invalidate(allProductsProvider);
      ref.invalidate(filteredProductsProvider);

      if (mounted) {
        context.showSnackBar('Product deleted');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to delete product', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditing ? 'Edit Product' : 'Add Product',
          style: AppTextStyles.heading3,
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorRed),
              onPressed: _isLoading ? null : _deleteProduct,
            ),
        ],
      ),
      body: _isLoading && !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // ── Image Picker ──
                  _buildImagePicker(),
                  const SizedBox(height: AppSpacing.md),

                  // Name
                  _buildLabel('Product Name'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Enter product name'),
                    validator: (v) => Validators.required(v, 'Product name'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category
                  _buildLabel('Category'),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: _inputDecoration('Select category'),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                    validator: (v) =>
                        v == null ? 'Category is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Price
                  _buildLabel('Price'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _priceController,
                    decoration: _inputDecoration('0', prefixText: 'Rp '),
                    validator: Validators.price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Cost Price
                  _buildLabel('Cost Price (optional)'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _costPriceController,
                    decoration: _inputDecoration('0', prefixText: 'Rp '),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Description
                  _buildLabel('Description (optional)'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration('Enter description'),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Barcode
                  Row(
                    children: [
                      Expanded(child: _buildLabel('Barcode (optional)')),
                      if (widget.isEditing)
                        TextButton.icon(
                          onPressed: () => _openBarcodeLabelPrint(),
                          icon: const Icon(Icons.qr_code_rounded, size: 16),
                          label: const Text('Print Label'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.infoBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: _inputDecoration('Scan or enter barcode'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // SKU
                  _buildLabel('SKU (optional)'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _skuController,
                    decoration: _inputDecoration('Enter SKU'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Discount Percent
                  _buildLabel('Discount % (optional)'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _discountController,
                    decoration: _inputDecoration('0', suffixText: '%'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0 || parsed > 100) {
                        return 'Must be between 0 and 100';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Combo toggle
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.dashboard_customize_rounded,
                                color: AppColors.infoBlue, size: 22),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Produk Combo',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Paket bundel dengan pilihan produk',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isCombo,
                              activeColor: AppColors.primaryOrange,
                              onChanged: (v) =>
                                  setState(() => _isCombo = v),
                            ),
                          ],
                        ),
                        if (_isCombo && widget.isEditing) ...[
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                  '/settings/products/${widget.productId}/combo'),
                              icon: const Icon(
                                  Icons.settings_rounded,
                                  size: 18),
                              label: const Text(
                                  'Atur Pilihan Combo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.infoBlue,
                                side: const BorderSide(
                                    color: AppColors.infoBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_isCombo && !widget.isEditing) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Simpan produk dulu, lalu atur pilihan combo.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.warningAmber,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // BOM toggle
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.borderGrey.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.science_rounded,
                                color: AppColors.successGreen, size: 24),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Punya Resep (BOM)',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Kurangi bahan baku saat penjualan',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _hasBom,
                              activeColor: AppColors.primaryOrange,
                              onChanged: (v) =>
                                  setState(() => _hasBom = v),
                            ),
                          ],
                        ),
                        if (_hasBom && widget.isEditing) ...[
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                  '/settings/products/${widget.productId}/bom'),
                              icon: const Icon(
                                  Icons.settings_rounded,
                                  size: 18),
                              label: const Text(
                                  'Atur Resep BOM'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.successGreen,
                                side: const BorderSide(
                                    color: AppColors.successGreen),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                        if (_hasBom && !widget.isEditing) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Simpan produk dulu, lalu atur resep BOM.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.warningAmber,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Update Product'
                                  : 'Save Product',
                              style: AppTextStyles.buttonText,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }

  // ── Image Picker Widget ──

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Product Image (optional)'),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: _imagePath != null && (_imagePath!.isNotEmpty && (kIsWeb || file_helper.fileExistsSync(_imagePath!)))
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CrossPlatformImage(
                          imageUrl: _imagePath!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _imageActionButton(
                              icon: Icons.edit_rounded,
                              onTap: _pickImage,
                            ),
                            const SizedBox(width: 8),
                            _imageActionButton(
                              icon: Icons.close_rounded,
                              onTap: _removeImage,
                              color: AppColors.errorRed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: AppColors.textHint.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tap to add image',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _imageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
      prefixText: prefixText,
      prefixStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      suffixText: suffixText,
      suffixStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
    );
  }
}
