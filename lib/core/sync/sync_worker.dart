import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import 'sync_engine.dart';
import '../utils/logger.dart';

const syncTaskName = 'kompak_pos_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      AppLogger.info('Background sync task started: $task');
      final db = AppDatabase();
      final engine = SyncEngine(db);
      await engine.syncAll();
      await db.close();
      return true;
    } catch (e) {
      AppLogger.error('Background sync failed', e);
      return false;
    }
  });
}
