import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';

/// Watch all terminals for a specific store (reactive stream)
final terminalsProvider =
    StreamProvider.family<List<Terminal>, String>((ref, storeId) {
  final service = ref.watch(terminalServiceProvider);
  return service.watchByStore(storeId);
});

/// Get active terminals for a store
final activeTerminalsProvider =
    FutureProvider.family<List<Terminal>, String>((ref, storeId) {
  final service = ref.watch(terminalServiceProvider);
  return service.getActiveByStore(storeId);
});

/// Get a single terminal by ID
final terminalDetailProvider =
    FutureProvider.family<Terminal?, String>((ref, id) {
  final service = ref.watch(terminalServiceProvider);
  return service.getById(id);
});
