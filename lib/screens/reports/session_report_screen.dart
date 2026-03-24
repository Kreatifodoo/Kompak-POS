import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../models/session_report_model.dart';
import '../../modules/core_providers.dart';
import '../../modules/pos_session/pos_session_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/printer/printer_providers.dart';

/// Session report list screen
class SessionReportListScreen extends ConsumerWidget {
  const SessionReportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);

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
        title: Text('Laporan Session', style: AppTextStyles.heading3),
      ),
      body: historyAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada riwayat session',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sessionHistoryProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: sessions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _SessionTile(session: sessions[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final PosSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClosed = session.status == 'closed';
    final duration = (session.closedAt ?? DateTime.now())
        .difference(session.openedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final durationText = hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/settings/reports/sessions/${session.id}'),
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
                  color: (isClosed
                          ? AppColors.successGreen
                          : AppColors.warningAmber)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isClosed
                      ? Icons.check_circle_rounded
                      : Icons.access_time_rounded,
                  color:
                      isClosed ? AppColors.successGreen : AppColors.warningAmber,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.dateTime(session.openedAt),
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Durasi: $durationText  •  Kas Awal: ${Formatters.currency(session.openingCash)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: (isClosed
                          ? AppColors.successGreen
                          : AppColors.warningAmber)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isClosed ? 'Closed' : 'Open',
                  style: AppTextStyles.caption.copyWith(
                    color: isClosed
                        ? AppColors.successGreen
                        : AppColors.warningAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
}

/// Session report detail screen
class SessionReportDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionReportDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(sessionReportProvider(sessionId));

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
        title: Text('Detail Session', style: AppTextStyles.heading3),
        actions: [
          reportAsync.whenOrNull(
                data: (report) => IconButton(
                  icon: const Icon(Icons.print_rounded,
                      color: AppColors.primaryOrange),
                  onPressed: () => _printReport(context, ref, report),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: reportAsync.when(
        data: (report) => _buildReport(context, report),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildReport(BuildContext context, SessionReport report) {
    final hours = report.duration.inHours;
    final minutes = report.duration.inMinutes % 60;
    final durationText = hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session info card
          _buildCard(
            title: 'Informasi Session',
            children: [
              _buildInfoRow('Kasir', report.cashierName),
              _buildInfoRow('Dibuka', Formatters.dateTime(report.openedAt)),
              if (report.closedAt != null)
                _buildInfoRow('Ditutup', Formatters.dateTime(report.closedAt!)),
              _buildInfoRow('Durasi', durationText),
              _buildInfoRow('Total Transaksi', '${report.totalOrders} order'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Sales summary
          _buildCard(
            title: 'Ringkasan Penjualan',
            children: [
              _buildAmountRow('Subtotal', report.totalSubtotal),
              if (report.totalDiscounts > 0)
                _buildAmountRow('Diskon', -report.totalDiscounts,
                    color: AppColors.discountRed),
              const Divider(),
              _buildAmountRow('Total Penjualan', report.totalSales,
                  bold: true, color: AppColors.primaryOrange),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Payment breakdown
          _buildCard(
            title: 'Rincian Pembayaran',
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Metode',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary))),
                    Expanded(
                        flex: 1,
                        child: Text('Jml',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary))),
                    Expanded(
                        flex: 3,
                        child: Text('Total',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary))),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              ...report.allBreakdowns.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text(b.method,
                                style: AppTextStyles.bodySmall)),
                        Expanded(
                            flex: 1,
                            child: Text('${b.count}',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall)),
                        Expanded(
                            flex: 3,
                            child: Text(
                                Formatters.currency(
                                    b.totalAmount - b.totalChange),
                                textAlign: TextAlign.right,
                                style: AppTextStyles.bodySmall)),
                      ],
                    ),
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Cash reconciliation
          _buildCard(
            title: 'Rekonsiliasi Kas',
            children: [
              _buildAmountRow('Saldo Awal', report.openingCash),
              _buildAmountRow('Kas Masuk', report.cashReceived,
                  color: AppColors.successGreen),
              _buildAmountRow('Kembalian', -report.cashChangeGiven,
                  color: AppColors.discountRed),
              const Divider(),
              _buildAmountRow('Kas Diharapkan', report.expectedClosingCash,
                  bold: true),
              if (report.actualClosingCash != null) ...[
                _buildAmountRow('Kas Aktual', report.actualClosingCash!),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: report.difference == 0
                        ? AppColors.successGreen.withOpacity(0.1)
                        : (report.difference ?? 0) > 0
                            ? AppColors.infoBlue.withOpacity(0.1)
                            : AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Selisih',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        report.difference == 0
                            ? 'Seimbang'
                            : (report.difference ?? 0) > 0
                                ? '+${Formatters.currency(report.difference!)} (Lebih)'
                                : '${Formatters.currency(report.difference!)} (Kurang)',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: report.difference == 0
                              ? AppColors.successGreen
                              : (report.difference ?? 0) > 0
                                  ? AppColors.infoBlue
                                  : AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildCard(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          Text(value,
              style:
                  AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)
                  : AppTextStyles.bodySmall),
          Text(
            '${amount < 0 ? '-' : ''}${Formatters.currency(amount.abs())}',
            style:
                (bold ? AppTextStyles.bodyMedium : AppTextStyles.bodySmall)
                    .copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport(
      BuildContext context, WidgetRef ref, SessionReport report) async {
    try {
      final receiptService = ref.read(receiptServiceProvider);
      final store = ref.read(currentStoreProvider);
      final printerService = ref.read(printerServiceProvider);
      final isConnected = ref.read(printerConnectedProvider);

      if (!isConnected) {
        context.showSnackBar('Printer tidak terhubung', isError: true);
        return;
      }

      final bytes = await receiptService.generateSessionReport(
        report: report,
        storeName: store?.name ?? 'Kompak Store',
        storeAddress: store?.address ?? '',
      );
      await printerService.printReceipt(bytes);
      context.showSnackBar('Laporan berhasil dicetak');
    } catch (e) {
      context.showSnackBar('Gagal mencetak: $e', isError: true);
    }
  }
}
