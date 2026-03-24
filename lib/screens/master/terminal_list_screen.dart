import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/terminal/terminal_providers.dart';

class TerminalListScreen extends ConsumerWidget {
  const TerminalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeId = ref.watch(currentStoreIdProvider);
    if (storeId == null) {
      return const Scaffold(
        body: Center(child: Text('No store selected')),
      );
    }

    final terminalsAsync = ref.watch(terminalsProvider(storeId));

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
        title: Text('Kelola Terminal', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => context.push('/settings/terminals/new'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: terminalsAsync.when(
        data: (terminals) {
          if (terminals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.point_of_sale_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada terminal',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tap + untuk menambah terminal/mesin kasir',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Info banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.infoBlue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.infoBlue, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Setiap terminal mewakili 1 mesin kasir. Assign user ke terminal di menu "Kelola Pengguna".',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.infoBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Terminal list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: terminals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _TerminalCard(terminal: terminals[index]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _TerminalCard extends ConsumerWidget {
  final Terminal terminal;
  const _TerminalCard({required this.terminal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/settings/terminals/${terminal.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: terminal.isActive
                      ? AppColors.primaryOrange.withOpacity(0.1)
                      : AppColors.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.point_of_sale_rounded,
                  color: terminal.isActive
                      ? AppColors.primaryOrange
                      : AppColors.textHint,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terminal.name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kode: ${terminal.code}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    if (terminal.printerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Printer: ${terminal.printerName}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.successGreen),
                      ),
                    ],
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: terminal.isActive
                      ? AppColors.successGreen.withOpacity(0.1)
                      : AppColors.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  terminal.isActive ? 'Aktif' : 'Nonaktif',
                  style: AppTextStyles.caption.copyWith(
                    color: terminal.isActive
                        ? AppColors.successGreen
                        : AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
