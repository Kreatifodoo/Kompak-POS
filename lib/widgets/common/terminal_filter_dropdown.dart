import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../modules/orders/order_providers.dart';
import '../../modules/terminal/terminal_providers.dart';

/// Dropdown to filter data by terminal.
/// Branch-aware: respects the selected branch filter for HQ users.
/// Shows "Semua Terminal" + list of active terminals for the effective store(s).
class TerminalFilterDropdown extends ConsumerWidget {
  const TerminalFilterDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalsAsync = ref.watch(branchAwareTerminalsProvider);
    final selected = ref.watch(selectedTerminalFilterProvider);

    return terminalsAsync.when(
      data: (terminals) {
        if (terminals.length <= 1) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGrey),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: terminals.any((t) => t.id == selected) ? selected : null,
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
                      Icon(Icons.point_of_sale_rounded,
                          size: 16, color: AppColors.textHint),
                      SizedBox(width: 6),
                      Text('Semua Terminal'),
                    ],
                  ),
                ),
                ...terminals.map((t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.point_of_sale_rounded,
                              size: 16, color: AppColors.primaryOrange),
                          const SizedBox(width: 6),
                          Text(t.name),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) {
                ref.read(selectedTerminalFilterProvider.notifier).state = value;
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
