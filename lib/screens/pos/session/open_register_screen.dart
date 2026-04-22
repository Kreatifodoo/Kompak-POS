import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/database/app_database.dart';
import '../../../modules/auth/auth_providers.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/pos_session/pos_session_providers.dart';
import '../../../modules/terminal/terminal_providers.dart';

class OpenRegisterScreen extends ConsumerStatefulWidget {
  const OpenRegisterScreen({super.key});

  @override
  ConsumerState<OpenRegisterScreen> createState() => _OpenRegisterScreenState();
}

class _OpenRegisterScreenState extends ConsumerState<OpenRegisterScreen> {
  String _cashInput = '0';
  bool _isLoading = false;
  String? _selectedTerminalId; // For admin/owner terminal selection

  double get _cashAmount => double.tryParse(_cashInput) ?? 0;

  /// Whether this user needs to pick a terminal (admin/owner without assigned terminal)
  bool get _needsTerminalSelection {
    final user = ref.read(currentUserProvider);
    final assignedTerminal = ref.read(currentTerminalIdProvider);
    if (assignedTerminal != null) return false;
    final role = user?.role ?? '';
    return ['owner', 'admin', 'branch_manager'].contains(role);
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Logout',
            onPressed: () async {
              await performLogout(ref);
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
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
          const SizedBox(height: AppSpacing.sm),

          // Terminal selector for admin/owner without assigned terminal
          if (_needsTerminalSelection) _buildTerminalSelector(),

          const SizedBox(height: AppSpacing.md),

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

  Widget _buildTerminalSelector() {
    final storeId = ref.watch(currentStoreIdProvider);
    if (storeId == null) return const SizedBox.shrink();

    final terminalsAsync = ref.watch(activeTerminalsProvider(storeId));

    return terminalsAsync.when(
      data: (terminals) {
        if (terminals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warningAmber, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Belum ada terminal. Buat terminal di Settings → Kelola Terminal.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warningAmber),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Auto-select first terminal if nothing selected
        _selectedTerminalId ??= terminals.first.id;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTerminalId,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: AppTextStyles.bodyMedium,
                hint: Text('Pilih Terminal',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint)),
                items: terminals
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Row(
                            children: [
                              const Icon(Icons.point_of_sale_rounded,
                                  size: 18, color: AppColors.primaryOrange),
                              const SizedBox(width: AppSpacing.sm),
                              Text(t.name),
                              if (t.code.isNotEmpty) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Text('(${t.code})',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.textHint)),
                              ],
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedTerminalId = value),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
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

      // Multi-terminal: use assigned terminal, admin-selected, or legacy fallback
      final String terminalId = ref.read(currentTerminalIdProvider) ??
          _selectedTerminalId ??
          ref.read(terminalIdProvider);
      await service.openSession(
        storeId: storeId,
        cashierId: currentUser.id,
        terminalId: terminalId,
        openingCash: _cashAmount,
      );

      // Set terminal context if admin selected a terminal
      if (_selectedTerminalId != null && ref.read(currentTerminalIdProvider) == null) {
        ref.read(currentTerminalIdProvider.notifier).state = _selectedTerminalId;
        final db = ref.read(databaseProvider);
        final terminal = await db.terminalDao.getById(_selectedTerminalId!);
        ref.read(currentTerminalProvider.notifier).state = terminal;
      }

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
