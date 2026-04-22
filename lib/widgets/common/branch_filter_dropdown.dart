import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/orders/order_providers.dart';

/// Dropdown to filter data by branch.
/// Only visible for HQ users. Shows "Semua Cabang" + list of branches.
class BranchFilterDropdown extends ConsumerWidget {
  const BranchFilterDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHQ = ref.watch(isHQUserProvider);
    if (!isHQ) return const SizedBox.shrink();

    final branchesAsync = ref.watch(branchesProvider);
    final selected = ref.watch(selectedBranchIdProvider);

    return branchesAsync.when(
      data: (branches) {
        if (branches.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGrey),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selected,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppColors.textSecondary),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_mall_directory_rounded,
                          size: 16, color: AppColors.textHint),
                      SizedBox(width: 6),
                      Text('Semua Cabang'),
                    ],
                  ),
                ),
                ...branches.map((b) => DropdownMenuItem<String?>(
                      value: b.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_rounded,
                              size: 16, color: Colors.teal),
                          const SizedBox(width: 6),
                          Text(b.name),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) {
                ref.read(selectedBranchIdProvider.notifier).state = value;
                // Reset terminal filter when branch changes to avoid showing
                // a terminal that doesn't belong to the newly selected branch.
                ref.read(selectedTerminalFilterProvider.notifier).state = null;
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
