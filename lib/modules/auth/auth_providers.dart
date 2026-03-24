import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';

final currentUserProvider = StateProvider<User?>((ref) => null);
final currentStoreProvider = StateProvider<Store?>((ref) => null);
final currentStoreIdProvider = StateProvider<String?>((ref) => null);

final pinEntryProvider = StateProvider<String>((ref) => '');

final authLoadingProvider = StateProvider<bool>((ref) => false);

final authenticateProvider = FutureProvider.family<User?, String>((ref, pin) async {
  final authService = ref.read(authServiceProvider);
  final db = ref.read(databaseProvider);
  final user = await authService.authenticateByPin(pin);
  if (user != null) {
    ref.read(currentUserProvider.notifier).state = user;
    await authService.saveSession(user.id, terminalId: user.terminalId);
    // Set store state so master-data screens can load
    if (user.storeId != null) {
      ref.read(currentStoreIdProvider.notifier).state = user.storeId;
      await authService.setCurrentStoreId(user.storeId!);
      final store = await db.storeDao.getStoreById(user.storeId!);
      if (store != null) {
        ref.read(currentStoreProvider.notifier).state = store;
      }
    }
    // Set terminal context
    if (user.terminalId != null) {
      ref.read(currentTerminalIdProvider.notifier).state = user.terminalId;
      await authService.setCurrentTerminalId(user.terminalId!);
      final terminal = await db.terminalDao.getById(user.terminalId!);
      ref.read(currentTerminalProvider.notifier).state = terminal;
    }
  }
  return user;
});

final restoreSessionProvider = FutureProvider<User?>((ref) async {
  final authService = ref.read(authServiceProvider);
  final db = ref.read(databaseProvider);
  final user = await authService.getCurrentUser();
  if (user != null) {
    ref.read(currentUserProvider.notifier).state = user;
    if (user.storeId != null) {
      ref.read(currentStoreIdProvider.notifier).state = user.storeId;
      final store = await db.storeDao.getStoreById(user.storeId!);
      if (store != null) {
        ref.read(currentStoreProvider.notifier).state = store;
      }
    }
    // Restore terminal context
    if (user.terminalId != null) {
      ref.read(currentTerminalIdProvider.notifier).state = user.terminalId;
      final terminal = await db.terminalDao.getById(user.terminalId!);
      ref.read(currentTerminalProvider.notifier).state = terminal;
    }
  }
  return user;
});
