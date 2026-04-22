import 'package:dio/dio.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../config/env_config.dart';
import '../utils/logger.dart';

class SyncEngine {
  final AppDatabase db;

  SyncEngine(this.db);

  Future<void> syncAll() async {
    try {
      AppLogger.info('Starting sync...');
      final pending = await db.syncQueueDao.getPending(limit: EnvConfig.syncBatchSize);

      if (pending.isEmpty) {
        AppLogger.info('No pending sync items');
        return;
      }

      final dio = ApiClient.instance;

      for (final item in pending) {
        try {
          await dio.post(
            ApiEndpoints.sync,
            data: {
              'table': item.targetTable,
              'record_id': item.recordId,
              'operation': item.operation,
              'payload': item.payload,
            },
          );
          await db.syncQueueDao.markSynced(item.id);
          AppLogger.info('Synced: ${item.targetTable}/${item.recordId}');
        } on DioException catch (e) {
          AppLogger.error('Sync failed for ${item.recordId}', e);
          await db.syncQueueDao.markFailed(item.id);
        }
      }

      // Cleanup old synced + permanently-failed items
      await db.syncQueueDao.deleteOldSynced();
      await db.syncQueueDao.deleteOldFailed(); // BUG-SIT-003 FIX
      AppLogger.info('Sync completed');
    } catch (e) {
      AppLogger.error('Sync engine error', e);
    }
  }
}
