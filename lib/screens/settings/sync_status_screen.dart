import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/sync/sync_providers.dart';
import '../../modules/core_providers.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() =>
      _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  List<SyncQueueData> _recentSyncItems = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadSyncHistory();
  }

  Future<void> _loadSyncHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final db = ref.read(databaseProvider);
      final items = await db.syncQueueDao.getPending(limit: 20);
      if (mounted) {
        setState(() {
          _recentSyncItems = items;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncPendingAsync = ref.watch(syncPendingCountProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final isSyncing = ref.watch(isSyncingProvider);

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
        title: Text(
          'Sync Status',
          style: AppTextStyles.heading3,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Status icon
                  _buildStatusIcon(isSyncing, syncPendingAsync),
                  const SizedBox(height: AppSpacing.md),

                  // Status text
                  Text(
                    isSyncing
                        ? 'Syncing...'
                        : syncPendingAsync.when(
                            data: (count) => count > 0
                                ? 'Pending Sync'
                                : 'All Synced',
                            loading: () => 'Checking...',
                            error: (_, __) => 'Sync Error',
                          ),
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Pending count
                  syncPendingAsync.when(
                    data: (count) => Text(
                      count > 0
                          ? '$count items pending'
                          : 'Everything is up to date',
                      style: AppTextStyles.bodySmall,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text(
                      'Error checking sync status',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Last sync time & sync now
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Last Sync',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        lastSyncTime != null
                            ? Formatters.dateTime(lastSyncTime)
                            : 'Never',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSyncing ? null : () => _syncNow(),
                      icon: isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.sync_rounded,
                              color: Colors.white),
                      label: Text(
                        isSyncing ? 'Syncing...' : 'Sync Now',
                        style: AppTextStyles.buttonText,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        disabledBackgroundColor: AppColors.borderGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Recent sync items
            Text(
              'Pending Items',
              style: AppTextStyles.heading3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentSyncItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: AppColors.successGreen.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No pending items',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_recentSyncItems.length, (index) {
                final item = _recentSyncItems[index];
                return _buildSyncItemTile(item);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(
    bool isSyncing,
    AsyncValue<int> pendingAsync,
  ) {
    if (isSyncing) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  AlwaysStoppedAnimation(AppColors.primaryOrange),
            ),
          ),
        ),
      );
    }

    final hasPending = pendingAsync.when(
      data: (count) => count > 0,
      loading: () => false,
      error: (_, __) => true,
    );

    final hasError = pendingAsync.hasError;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: hasError
            ? AppColors.errorRed.withOpacity(0.1)
            : hasPending
                ? AppColors.warningAmber.withOpacity(0.1)
                : AppColors.successGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        hasError
            ? Icons.error_outline_rounded
            : hasPending
                ? Icons.sync_rounded
                : Icons.check_circle_rounded,
        color: hasError
            ? AppColors.errorRed
            : hasPending
                ? AppColors.warningAmber
                : AppColors.successGreen,
        size: 36,
      ),
    );
  }

  Widget _buildSyncItemTile(SyncQueueData item) {
    IconData icon;
    Color statusColor;

    switch (item.status) {
      case 'pending':
        icon = Icons.schedule_rounded;
        statusColor = AppColors.warningAmber;
        break;
      case 'syncing':
        icon = Icons.sync_rounded;
        statusColor = AppColors.infoBlue;
        break;
      case 'synced':
        icon = Icons.check_circle_rounded;
        statusColor = AppColors.successGreen;
        break;
      case 'failed':
        icon = Icons.error_outline_rounded;
        statusColor = AppColors.errorRed;
        break;
      default:
        icon = Icons.help_outline_rounded;
        statusColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.targetTable} - ${item.operation}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  Formatters.dateTime(item.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.status.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    ref.read(isSyncingProvider.notifier).state = true;

    try {
      // Simulate sync process - in production this would call actual sync service
      await Future.delayed(const Duration(seconds: 2));

      ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();

      if (mounted) {
        context.showSnackBar('Sync completed');
        _loadSyncHistory();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Sync failed: $e', isError: true);
      }
    } finally {
      ref.read(isSyncingProvider.notifier).state = false;
    }
  }
}
