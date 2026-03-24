import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';
import 'sync_engine.dart';
import '../database/app_database.dart';

class ConnectivityMonitor {
  final AppDatabase db;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  ConnectivityMonitor(this.db);

  void startMonitoring() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline && _wasOffline) {
        AppLogger.info('Connection restored. Triggering sync...');
        _triggerSync();
      }

      _wasOffline = !isOnline;
    });
  }

  Future<void> _triggerSync() async {
    try {
      final engine = SyncEngine(db);
      await engine.syncAll();
    } catch (e) {
      AppLogger.error('Connectivity sync failed', e);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
