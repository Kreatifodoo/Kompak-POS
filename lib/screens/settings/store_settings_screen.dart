import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/file_helper.dart' as file_helper;
import '../../core/widgets/cross_platform_image.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';

class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState
    extends ConsumerState<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _taxRateController;
  late TextEditingController _currencyController;
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;
  bool _isSaving = false;
  bool _isLoaded = false;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _taxRateController = TextEditingController();
    _currencyController = TextEditingController();
    _receiptHeaderController = TextEditingController();
    _receiptFooterController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxRateController.dispose();
    _currencyController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  void _loadStoreData(Store store) {
    if (!_isLoaded) {
      _nameController.text = store.name;
      _addressController.text = store.address ?? '';
      _phoneController.text = store.phone ?? '';
      _taxRateController.text =
          (store.taxRate * 100).toStringAsFixed(0);
      _currencyController.text = store.currencySymbol;
      _receiptHeaderController.text = store.receiptHeader ?? '';
      _receiptFooterController.text = store.receiptFooter ?? '';
      _logoPath = store.logoUrl;
      _isLoaded = true;
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (kIsWeb) {
      // On web, use picked path directly
      setState(() => _logoPath = picked.path);
    } else {
      // Mobile: Copy to app's permanent directory
      final appDir = await getApplicationDocumentsDirectory();
      final logoDirPath = p.join(appDir.path, 'logos');
      await file_helper.createDirectory(logoDirPath);

      final ext = p.extension(picked.path);
      final destPath = p.join(logoDirPath, 'store_logo$ext');
      final savedPath = await file_helper.copyFile(picked.path, destPath);

      if (savedPath != null) {
        setState(() => _logoPath = savedPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStore = ref.watch(currentStoreProvider);
    final storeId = ref.watch(currentStoreIdProvider);

    if (currentStore != null) {
      _loadStoreData(currentStore);
    }

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
          'Store Settings',
          style: AppTextStyles.heading3,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store logo — tap to change
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.borderGrey,
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _logoPath != null && (_logoPath!.isNotEmpty && (kIsWeb || file_helper.fileExistsSync(_logoPath!)))
                            ? CrossPlatformImage(
                                imageUrl: _logoPath!,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                              )
                            : const Icon(
                                Icons.store_rounded,
                                color: AppColors.primaryOrange,
                                size: 48,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Tap to change logo',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Form fields
              _buildFormField(
                label: 'Store Name',
                controller: _nameController,
                hint: 'Enter store name',
                icon: Icons.store_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Store name is required';
                  }
                  return null;
                },
              ),

              _buildFormField(
                label: 'Address',
                controller: _addressController,
                hint: 'Enter store address',
                icon: Icons.location_on_rounded,
                maxLines: 2,
              ),

              _buildFormField(
                label: 'Phone',
                controller: _phoneController,
                hint: 'Enter phone number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),

              _buildFormField(
                label: 'Tax Rate (%)',
                controller: _taxRateController,
                hint: 'e.g. 11',
                icon: Icons.percent_rounded,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final rate = double.tryParse(value);
                    if (rate == null || rate < 0 || rate > 100) {
                      return 'Enter a valid tax rate (0-100)';
                    }
                  }
                  return null;
                },
              ),

              _buildFormField(
                label: 'Currency Symbol',
                controller: _currencyController,
                hint: 'e.g. Rp',
                icon: Icons.currency_exchange_rounded,
              ),

              const SizedBox(height: AppSpacing.md),
              Text(
                'Receipt Settings',
                style: AppTextStyles.heading3.copyWith(fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Custom header & footer text that will appear on printed receipts.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              _buildFormField(
                label: 'Receipt Header',
                controller: _receiptHeaderController,
                hint: 'e.g. Selamat datang di toko kami!',
                icon: Icons.vertical_align_top_rounded,
                maxLines: 2,
              ),

              _buildFormField(
                label: 'Receipt Footer',
                controller: _receiptFooterController,
                hint: 'e.g. Terima kasih atas kunjungan Anda',
                icon: Icons.vertical_align_bottom_rounded,
                maxLines: 2,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () => _saveSettings(storeId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    disabledBackgroundColor: AppColors.borderGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded,
                                color: Colors.white),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Save Settings',
                              style: AppTextStyles.buttonText,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textHint),
              prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.borderGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primaryOrange, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.errorRed),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings(String? storeId) async {
    if (!_formKey.currentState!.validate()) return;
    if (storeId == null) {
      context.showSnackBar('No store selected', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final taxRate =
          (double.tryParse(_taxRateController.text) ?? 11) / 100;

      final companion = StoresCompanion(
        id: Value(storeId),
        name: Value(_nameController.text.trim()),
        address: Value(_addressController.text.trim()),
        phone: Value(_phoneController.text.trim()),
        taxRate: Value(taxRate),
        currencySymbol: Value(_currencyController.text.trim().isEmpty
            ? 'Rp'
            : _currencyController.text.trim()),
        logoUrl: Value(_logoPath),
        receiptHeader: Value(_receiptHeaderController.text.trim().isEmpty
            ? null
            : _receiptHeaderController.text.trim()),
        receiptFooter: Value(_receiptFooterController.text.trim().isEmpty
            ? null
            : _receiptFooterController.text.trim()),
        updatedAt: Value(DateTime.now()),
      );

      await db.storeDao.updateStore(companion);

      // Refresh the store in state
      final updatedStore = await db.storeDao.getStoreById(storeId);
      if (updatedStore != null) {
        ref.read(currentStoreProvider.notifier).state = updatedStore;
      }

      if (mounted) {
        context.showSnackBar('Store settings saved');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
