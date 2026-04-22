import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/attendance/attendance_providers.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(currentStoreProvider);
    final historyAsync = ref.watch(
      attendanceHistoryProvider(store?.id ?? ''),
    );

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
        title: Text('Riwayat Absensi', style: AppTextStyles.heading3),
      ),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada riwayat absensi',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<Attendance>>{};
          for (final r in records) {
            final key = Formatters.date(r.timestamp);
            grouped.putIfAbsent(key, () => []).add(r);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.elementAt(index);
              final dayRecords = grouped[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, bottom: AppSpacing.sm),
                    child: Text(dateKey,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  ...dayRecords.map((r) => _buildRecordCard(r)),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildRecordCard(Attendance record) {
    final isIn = record.type == 'clock_in';
    final color = isIn ? AppColors.successGreen : AppColors.warningAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 64,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              image: File(record.photoPath).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(record.photoPath)),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: AppColors.borderGrey,
            ),
            child: !File(record.photoPath).existsSync()
                ? const Icon(Icons.person, color: AppColors.textHint)
                : null,
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isIn ? 'Masuk' : 'Pulang',
                          style: AppTextStyles.caption.copyWith(
                              color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Formatters.time(record.timestamp),
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (record.address.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            record.address,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (record.address.isEmpty)
                    Text(
                      '${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  if (record.isMockLocation)
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 12, color: AppColors.errorRed),
                        const SizedBox(width: 2),
                        Text(
                          'Mock Location',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.errorRed),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Telegram status
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(
              record.telegramSent
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              size: 18,
              color: record.telegramSent
                  ? AppColors.successGreen
                  : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
