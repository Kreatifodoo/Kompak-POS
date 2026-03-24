import '../utils/logger.dart';

/// Web stub — background sync not supported on web.
/// Web is always online, so sync happens in real-time.
Future<void> initBackgroundSync() async {
  AppLogger.info('Web mode: background sync skipped (always online)');
}
