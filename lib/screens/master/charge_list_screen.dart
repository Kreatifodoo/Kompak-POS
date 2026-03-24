import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../models/enums.dart';
import '../../modules/charge/charge_providers.dart';
import '../../modules/core_providers.dart';

class ChargeListScreen extends ConsumerWidget {
  const ChargeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargesAsync = ref.watch(chargesProvider);

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
        title: Text('Master Biaya', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => context.push('/settings/charges/new'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: chargesAsync.when(
        data: (charges) {
          if (charges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada biaya',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tap + untuk menambahkan',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: charges.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _ChargeTile(charge: charges[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ChargeTile extends ConsumerWidget {
  final Charge charge;
  const _ChargeTile({required this.charge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategori = ChargeKategori.fromDb(charge.kategori);
    final tipe = ChargeTipe.fromDb(charge.tipe);

    final kategoriColor = switch (kategori) {
      ChargeKategori.pajak => AppColors.infoBlue,
      ChargeKategori.layanan => AppColors.warningAmber,
      ChargeKategori.potongan => AppColors.discountRed,
    };

    final nilaiLabel = tipe == ChargeTipe.persentase
        ? '${charge.nilai.toStringAsFixed(charge.nilai.truncateToDouble() == charge.nilai ? 0 : 1)}%'
        : Formatters.currency(charge.nilai);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/settings/charges/${charge.id}/edit'),
        onLongPress: () => _showDeleteDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kategoriColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _kategoriIcon(kategori),
                  color: kategoriColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(charge.namaBiaya,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kategoriColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            kategori.label,
                            style: AppTextStyles.caption.copyWith(
                              color: kategoriColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          nilaiLabel,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${charge.urutan}',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (charge.isActive
                          ? AppColors.successGreen
                          : Colors.grey)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  charge.isActive ? 'Aktif' : 'Nonaktif',
                  style: AppTextStyles.caption.copyWith(
                    color:
                        charge.isActive ? AppColors.successGreen : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  IconData _kategoriIcon(ChargeKategori k) => switch (k) {
        ChargeKategori.pajak => Icons.account_balance_rounded,
        ChargeKategori.layanan => Icons.room_service_rounded,
        ChargeKategori.potongan => Icons.discount_rounded,
      };

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Biaya'),
        content: Text('Hapus "${charge.namaBiaya}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(chargeServiceProvider)
                  .deleteCharge(charge.id);
              ref.invalidate(chargesProvider);
            },
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }
}
