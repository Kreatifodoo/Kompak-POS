import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../modules/core_providers.dart';
import '../../modules/promotion/promotion_providers.dart';

class PromotionListScreen extends ConsumerWidget {
  const PromotionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(promotionsProvider);

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
        title: Text('Master Promosi', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/promotions/new'),
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: promotionsAsync.when(
        data: (promotions) {
          if (promotions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 64, color: AppColors.textHint.withOpacity(0.4)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada promosi',
                      style: AppTextStyles.heading3
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Tap + untuk membuat promosi baru',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: promotions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _PromotionTile(promotion: promotions[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _PromotionTile extends ConsumerWidget {
  final Promotion promotion;

  const _PromotionTile({required this.promotion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipeProgram = PromotionTipeProgram.fromDb(promotion.tipeProgram);
    final tipeReward = PromotionTipeReward.fromDb(promotion.tipeReward);
    final programColor = _programColor(tipeProgram);
    final programIcon = _programIcon(tipeProgram);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/settings/promotions/${promotion.id}/edit'),
        onLongPress: () => _showDeleteDialog(context, ref),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: programColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(programIcon, color: programColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promotion.namaPromo,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildBadge(tipeProgram.label, programColor),
                        const SizedBox(width: 6),
                        Text(
                          _rewardSummary(tipeReward),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _validityText(),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: promotion.isActive
                          ? AppColors.successGreen.withOpacity(0.1)
                          : AppColors.textHint.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      promotion.isActive ? 'Aktif' : 'Nonaktif',
                      style: AppTextStyles.caption.copyWith(
                        color: promotion.isActive
                            ? AppColors.successGreen
                            : AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (promotion.maxUsage > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${promotion.usageCount}/${promotion.maxUsage}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  String _rewardSummary(PromotionTipeReward tipe) {
    switch (tipe) {
      case PromotionTipeReward.diskonPersentase:
        return '${promotion.nilaiReward.toStringAsFixed(promotion.nilaiReward.truncateToDouble() == promotion.nilaiReward ? 0 : 1)}%';
      case PromotionTipeReward.diskonNominal:
        return Formatters.currency(promotion.nilaiReward);
      case PromotionTipeReward.produkGratis:
        return 'Gratis ${promotion.nilaiReward.toInt()} item';
    }
  }

  String _validityText() {
    final start = Formatters.date(promotion.startDate);
    if (promotion.endDate != null) {
      return '$start - ${Formatters.date(promotion.endDate!)}';
    }
    return 'Mulai $start';
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10),
      ),
    );
  }

  Color _programColor(PromotionTipeProgram tipe) {
    switch (tipe) {
      case PromotionTipeProgram.otomatis:
        return AppColors.successGreen;
      case PromotionTipeProgram.kodeDiskon:
        return AppColors.infoBlue;
      case PromotionTipeProgram.beliXGratisY:
        return Colors.purple;
    }
  }

  IconData _programIcon(PromotionTipeProgram tipe) {
    switch (tipe) {
      case PromotionTipeProgram.otomatis:
        return Icons.auto_awesome_rounded;
      case PromotionTipeProgram.kodeDiskon:
        return Icons.confirmation_number_rounded;
      case PromotionTipeProgram.beliXGratisY:
        return Icons.card_giftcard_rounded;
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Promosi', style: AppTextStyles.heading3),
        content: Text(
          'Hapus "${promotion.namaPromo}"?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.promotionDao.deletePromotion(promotion.id);
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(promotionsProvider);
            },
            child: Text('Hapus',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }
}
