import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/lan_sync_service.dart';
import '../core_providers.dart';

final lanSyncServiceProvider = Provider<LanSyncService>((ref) {
  final service = LanSyncService(ref.watch(databaseProvider));
  ref.onDispose(() => service.stopServer());
  return service;
});

final lanServerRunningProvider = StateProvider<bool>((ref) => false);

final lanServerIpProvider = FutureProvider<String?>((ref) async {
  return LanSyncService.getLocalIp();
});
