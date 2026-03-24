import 'package:workmanager/workmanager.dart';
import '../sync/sync_worker.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

/// Initialize Workmanager for background sync (Android/iOS only)
Future<void> initBackgroundSync() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Register periodic sync task (minimum 15 minutes on Android)
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: Duration(minutes: AppConfig.syncIntervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    AppLogger.info('Background sync initialized');
  } catch (e) {
    AppLogger.error('Failed to initialize background sync', e);
  }
}
