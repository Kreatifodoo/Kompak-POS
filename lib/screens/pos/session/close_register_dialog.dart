import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../models/session_report_model.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/pos_session/pos_session_providers.dart';
import '../../../modules/auth/auth_providers.dart';
import '../../../modules/pos/cart_providers.dart';
import '../../../modules/printer/printer_providers.dart';

class CloseRegisterDialog extends ConsumerStatefulWidget {
  final String sessionId;

  const CloseRegisterDialog({super.key, required this.sessionId});

  @override
  ConsumerState<CloseRegisterDialog> createState() =>
      _CloseRegisterDialogState();
}

class _CloseRegisterDialogState extends ConsumerState<CloseRegisterDialog> {
  final _closingCashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isClosing = false;
  bool _isPreFilled = false;

  @override
  void dispose() {
    _closingCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(sessionReportProvider(widget.sessionId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: reportAsync.when(
          data: (report) => _buildContent(report, scrollController),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(SessionReport report, ScrollController scrollController) {
    final closingCash =
        double.tryParse(_closingCashController.text) ?? report.expectedClosingCash;
    final difference = closingCash - report.expectedClosingCash;

    // Pre-fill with expected cash (only once, not during build)
    if (!_isPreFilled) {
      _isPreFilled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _closingCashController.text.isEmpty) {
          _closingCashController.text =
              report.expectedClosingCash.toStringAsFixed(0);
        }
      });
    }

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderGrey,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.point_of_sale_rounded,
                    color: AppColors.warningAmber, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tutup Kasir',
                        style: AppTextStyles.heading3),
                    Text(
                      'Kasir: ${report.cashierName}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Scrollable report
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Session info
              _buildInfoCard(report),
              const SizedBox(height: AppSpacing.md),
              // Sales summary
              _buildSalesSummaryCard(report),
              const SizedBox(height: AppSpacing.md),
              // Payment breakdown
              _buildPaymentBreakdownCard(report),
              const SizedBox(height: AppSpacing.md),
              // Cash reconciliation
              _buildCashReconciliationCard(report, difference),
              const SizedBox(height: AppSpacing.md),
              // Notes
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Catatan akhir sesi...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        // Action buttons
        _buildActionButtons(report),
      ],
    );
  }

  Widget _buildInfoCard(SessionReport report) {
    final hours = report.duration.inHours;
    final minutes = report.duration.inMinutes % 60;
    final durationText = hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m';

    return Card(
      elevation: 0,
      color: AppColors.surfaceGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildInfoRow('Dibuka', Formatters.dateTime(report.openedAt)),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow('Durasi', durationText),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow('Total Transaksi', '${report.totalOrders} order'),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryCard(SessionReport report) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan Penjualan',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            _buildAmountRow('Subtotal', report.totalSubtotal),
            if (report.totalDiscounts > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildAmountRow('Diskon', -report.totalDiscounts,
                  color: AppColors.discountRed),
            ],
            const Divider(height: AppSpacing.lg),
            _buildAmountRow('Total Penjualan', report.totalSales,
                bold: true, color: AppColors.primaryOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(SessionReport report) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rincian Pembayaran',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            // Header row
            Row(
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
            const Divider(height: AppSpacing.md),
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
                              Formatters.currency(b.totalAmount - b.totalChange),
                              textAlign: TextAlign.right,
                              style: AppTextStyles.bodySmall)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCashReconciliationCard(
      SessionReport report, double difference) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rekonsiliasi Kas',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            _buildAmountRow('Saldo Awal', report.openingCash),
            const SizedBox(height: AppSpacing.xs),
            _buildAmountRow('Kas Masuk', report.cashReceived,
                color: AppColors.successGreen),
            const SizedBox(height: AppSpacing.xs),
            _buildAmountRow('Kembalian', -report.cashChangeGiven,
                color: AppColors.discountRed),
            const Divider(height: AppSpacing.lg),
            _buildAmountRow('Kas Diharapkan', report.expectedClosingCash,
                bold: true),
            const SizedBox(height: AppSpacing.md),
            // Actual cash input
            TextField(
              controller: _closingCashController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Kas Aktual',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Difference display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: difference == 0
                    ? AppColors.successGreen.withOpacity(0.1)
                    : difference > 0
                        ? AppColors.infoBlue.withOpacity(0.1)
                        : AppColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selisih',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    difference == 0
                        ? 'Seimbang'
                        : difference > 0
                            ? '+${Formatters.currency(difference)} (Lebih)'
                            : '${Formatters.currency(difference)} (Kurang)',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: difference == 0
                          ? AppColors.successGreen
                          : difference > 0
                              ? AppColors.infoBlue
                              : AppColors.errorRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value,
            style:
                AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amount,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold
                ? AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)
                : AppTextStyles.bodySmall),
        Text(
          Formatters.currency(amount.abs()),
          style: (bold ? AppTextStyles.bodyMedium : AppTextStyles.bodySmall)
              .copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SessionReport report) {
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
        child: Row(
          children: [
            // Tutup Saja
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isClosing ? null : () => _closeSession(false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Tutup Saja',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Print & Tutup
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isClosing ? null : () => _closeSession(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    disabledBackgroundColor: AppColors.borderGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: _isClosing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.print_rounded, color: Colors.white),
                  label: Text(
                    'Print & Tutup',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeSession(bool printReport) async {
    setState(() => _isClosing = true);
    try {
      final service = ref.read(posSessionServiceProvider);
      // Generate report first to get expectedClosingCash for fallback
      final preReport = await service.generateReport(widget.sessionId);
      final closingCash =
          double.tryParse(_closingCashController.text) ?? preReport.expectedClosingCash;

      // Close the session
      await service.closeSession(
        widget.sessionId,
        closingCash: closingCash,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (printReport && mounted) {
        // Generate report for printing
        final report = await service.generateReport(widget.sessionId);
        final receiptService = ref.read(receiptServiceProvider);
        final store = ref.read(currentStoreProvider);
        final printerService = ref.read(printerServiceProvider);
        final isConnected = ref.read(printerConnectedProvider);

        if (isConnected) {
          final bytes = await receiptService.generateSessionReport(
            report: report,
            storeName: store?.name ?? 'Kompak Store',
            storeAddress: store?.address ?? '',
          );
          await printerService.printReceipt(bytes);
        } else {
          if (mounted) {
            context.showSnackBar('Printer tidak terhubung', isError: true);
          }
        }
      }

      // Clear cart and invalidate providers
      ref.read(cartProvider.notifier).clearCart();
      ref.invalidate(activeSessionProvider);
      ref.invalidate(sessionHistoryProvider);

      if (mounted) {
        Navigator.pop(context);
        context.showSnackBar('Kasir berhasil ditutup');
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Gagal menutup kasir: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }
}
