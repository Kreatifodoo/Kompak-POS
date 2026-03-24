import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../modules/auth/auth_providers.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/pos_session/pos_session_providers.dart';

class OpenRegisterScreen extends ConsumerStatefulWidget {
  const OpenRegisterScreen({super.key});

  @override
  ConsumerState<OpenRegisterScreen> createState() => _OpenRegisterScreenState();
}

class _OpenRegisterScreenState extends ConsumerState<OpenRegisterScreen> {
  String _cashInput = '0';
  bool _isLoading = false;

  double get _cashAmount => double.tryParse(_cashInput) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buka Kasir', style: AppTextStyles.heading3),
            if (ref.watch(currentTerminalProvider) != null)
              Text(
                'Terminal: ${ref.watch(currentTerminalProvider)!.name}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Header icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 40,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Masukkan Saldo Awal Kas',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hitung uang tunai di laci kasir',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Amount display
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Saldo Awal',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Formatters.currency(_cashAmount),
                  style: AppTextStyles.priceLarge.copyWith(fontSize: 32),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Quick amount buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                _buildQuickButton(0),
                const SizedBox(width: AppSpacing.sm),
                _buildQuickButton(100000),
                const SizedBox(width: AppSpacing.sm),
                _buildQuickButton(200000),
                const SizedBox(width: AppSpacing.sm),
                _buildQuickButton(500000),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Numeric keypad
          Expanded(child: _buildNumericKeypad()),

          // Open button
          _buildOpenButton(),
        ],
      ),
    );
  }

  Widget _buildQuickButton(double amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _cashInput = amount.toStringAsFixed(0);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              amount == 0 ? 'Rp 0' : Formatters.currency(amount),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', 'del'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: keys.map((row) {
          return Expanded(
            child: Row(
              children: row.map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color:
                          key == 'del' ? AppColors.surfaceGrey : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onKeyTap(key),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderGrey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: key == 'del'
                                ? const Icon(Icons.backspace_outlined,
                                    color: AppColors.textPrimary, size: 22)
                                : Text(
                                    key,
                                    style: AppTextStyles.heading3
                                        .copyWith(fontSize: 20),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'del') {
        if (_cashInput.isNotEmpty && _cashInput != '0') {
          _cashInput = _cashInput.substring(0, _cashInput.length - 1);
          if (_cashInput.isEmpty) _cashInput = '0';
        }
      } else {
        if (_cashInput == '0') {
          _cashInput = key == '00' ? '0' : key;
        } else if (_cashInput.length < 12) {
          _cashInput += key;
        }
      }
    });
  }

  Widget _buildOpenButton() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _openRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              disabledBackgroundColor: AppColors.borderGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_open_rounded, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Buka Kasir', style: AppTextStyles.buttonText),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRegister() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(posSessionServiceProvider);
      final storeId = ref.read(currentStoreIdProvider);
      final currentUser = ref.read(currentUserProvider);

      if (storeId == null || currentUser == null) {
        context.showSnackBar('User/store not found', isError: true);
        return;
      }

      // Multi-terminal: use assigned terminal, fallback to legacy generated ID
      final String terminalId =
          ref.read(currentTerminalIdProvider) ?? ref.read(terminalIdProvider);
      await service.openSession(
        storeId: storeId,
        cashierId: currentUser.id,
        terminalId: terminalId,
        openingCash: _cashAmount,
      );

      ref.invalidate(activeSessionProvider);
      // ISS-023: Navigate explicitly after opening register
      if (mounted) {
        context.go('/pos/catalog');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Gagal membuka kasir: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
