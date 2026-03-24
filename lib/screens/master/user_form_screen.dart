import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/terminal/terminal_providers.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final String? userId;

  const UserFormScreen({super.key, this.userId});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  String _selectedRole = 'cashier';
  String? _selectedTerminalId;
  bool _obscurePin = true;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isLoaded = false;

  bool get _isEditMode => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _pinController = TextEditingController();
    if (_isEditMode) {
      _loadUser();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    if (_isLoaded) return;

    setState(() => _isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      final user = await userService.getUserById(widget.userId!);
      if (user != null && mounted) {
        setState(() {
          _nameController.text = user.name;
          // Don't show hashed PIN — leave empty, user fills to change
          _pinController.text = '';
          _selectedRole = user.role;
          _selectedTerminalId = user.terminalId;
          _isLoaded = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('User not found', isError: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('Failed to load user: $e', isError: true);
      }
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) {
      context.showSnackBar('No store selected', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userService = ref.read(userServiceProvider);
      final pin = _pinController.text.trim();
      final name = _nameController.text.trim();

      // Check PIN uniqueness (skip if empty in edit mode — keeping old PIN)
      if (pin.isNotEmpty) {
        final isPinUnique = await userService.isPinUnique(
          pin,
          excludeUserId: widget.userId,
        );
        if (!isPinUnique) {
          if (mounted) {
            setState(() => _isSaving = false);
            context.showSnackBar('PIN is already in use by another user',
                isError: true);
          }
          return;
        }
      }

      if (_isEditMode) {
        await userService.updateUser(
          id: widget.userId!,
          name: name,
          pin: pin.isEmpty ? null : pin,
          role: _selectedRole,
          storeId: storeId,
          terminalId: _selectedTerminalId,
        );
      } else {
        await userService.createUser(
          name: name,
          pin: pin,
          role: _selectedRole,
          storeId: storeId,
          terminalId: _selectedTerminalId,
        );
      }

      if (mounted) {
        context.showSnackBar(
          _isEditMode ? 'User updated successfully' : 'User created successfully',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save user: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deactivateUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Deactivate User', style: AppTextStyles.heading3),
        content: Text(
          'Are you sure you want to deactivate this user? They will no longer be able to log in.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Deactivate',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userService = ref.read(userServiceProvider);
        await userService.deactivateUser(widget.userId!);
        if (mounted) {
          context.showSnackBar('User deactivated');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          context.showSnackBar('Failed to deactivate user: $e', isError: true);
        }
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
          _isEditMode ? 'Edit User' : 'Add User',
          style: AppTextStyles.heading3,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.primaryOrange,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Name field
                    _buildFormField(
                      label: 'Name',
                      controller: _nameController,
                      hint: 'Enter user name',
                      icon: Icons.person_outline_rounded,
                      validator: (value) =>
                          Validators.required(value, 'Name'),
                    ),

                    // PIN field
                    _buildPinField(),

                    // Role dropdown
                    _buildRoleDropdown(),

                    // Terminal assignment dropdown (only for cashier role)
                    if (_selectedRole == 'cashier') ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildTerminalDropdown(),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveUser,
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
                                    _isEditMode ? 'Update User' : 'Create User',
                                    style: AppTextStyles.buttonText,
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // Deactivate button (edit mode only)
                    if (_isEditMode) ...[
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _deactivateUser,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: AppColors.errorRed),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_off_rounded,
                                  color: AppColors.errorRed),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Deactivate User',
                                style: AppTextStyles.buttonText.copyWith(
                                  color: AppColors.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
            validator: validator,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              prefixIcon:
                  Icon(icon, color: AppColors.textSecondary, size: 20),
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
                borderSide:
                    const BorderSide(color: AppColors.primaryOrange, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.errorRed),
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

  Widget _buildPinField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PIN',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscurePin,
            validator: _isEditMode
                ? (value) {
                    // In edit mode, empty PIN = keep existing
                    if (value == null || value.isEmpty) return null;
                    if (value.length < 4 || value.length > 6) return 'PIN must be 4-6 digits';
                    if (!RegExp(r'^\d+$').hasMatch(value)) return 'PIN must be numeric';
                    return null;
                  }
                : Validators.pin,
            style: AppTextStyles.bodyMedium,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: _isEditMode ? 'Kosongkan jika tidak ingin mengubah PIN' : 'Enter 4-6 digit PIN',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
              counterText: '',
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
                borderSide:
                    const BorderSide(color: AppColors.primaryOrange, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.errorRed),
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

  Widget _buildRoleDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRole = value);
              }
            },
            validator: (value) =>
                Validators.required(value, 'Role'),
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined,
                  color: AppColors.textSecondary, size: 20),
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
                borderSide:
                    const BorderSide(color: AppColors.primaryOrange, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'admin',
                child: Text('Admin'),
              ),
              DropdownMenuItem(
                value: 'cashier',
                child: Text('Cashier'),
              ),
              DropdownMenuItem(
                value: 'kitchen',
                child: Text('Kitchen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalDropdown() {
    final storeId = ref.watch(currentStoreIdProvider);
    if (storeId == null) return const SizedBox.shrink();

    final terminalsAsync = ref.watch(terminalsProvider(storeId));

    return terminalsAsync.when(
      data: (terminals) {
        if (terminals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Belum ada terminal. Buat terminal di "Kelola Terminal" terlebih dahulu.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.warningAmber,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terminal Kasir',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: terminals.any((t) => t.id == _selectedTerminalId)
                    ? _selectedTerminalId
                    : null,
                onChanged: (value) {
                  setState(() => _selectedTerminalId = value);
                },
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.point_of_sale_rounded,
                      color: AppColors.textSecondary, size: 20),
                  hintText: 'Pilih terminal (opsional)',
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
                    borderSide:
                        const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tidak ditugaskan'),
                  ),
                  ...terminals.where((t) => t.isActive).map(
                        (t) => DropdownMenuItem<String>(
                          value: t.id,
                          child: Text('${t.name} (${t.code})'),
                        ),
                      ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
