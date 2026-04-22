import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../core/database/app_database.dart';

// attendanceServiceProvider is defined in core_providers.dart
// Re-exported here for convenience
export '../../modules/core_providers.dart' show attendanceServiceProvider;

/// Watch today's attendance records for the current user
final todayAttendanceProvider = StreamProvider<List<Attendance>>((ref) {
  final user = ref.watch(currentUserProvider);
  final store = ref.watch(currentStoreProvider);
  if (user == null || store == null) return Stream.value([]);

  final db = ref.watch(databaseProvider);
  return db.attendanceDao.watchTodayAttendance(user.id, store.id);
});

/// Watch today's attendance records for an arbitrary user
/// (used by the multi-user attendance flow).
final todayAttendanceForUserProvider =
    StreamProvider.family<List<Attendance>, String>((ref, userId) {
  final store = ref.watch(currentStoreProvider);
  if (store == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.attendanceDao.watchTodayAttendance(userId, store.id);
});

/// Next attendance type for the current user
final nextAttendanceTypeProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentUserProvider);
  final store = ref.watch(currentStoreProvider);
  if (user == null || store == null) return 'clock_in';

  final service = ref.watch(attendanceServiceProvider);
  return service.getNextType(user.id, store.id);
});

/// Next attendance type for an arbitrary user (multi-user flow).
final nextAttendanceTypeForUserProvider =
    FutureProvider.family<String, String>((ref, userId) async {
  final store = ref.watch(currentStoreProvider);
  if (store == null) return 'clock_in';
  final service = ref.watch(attendanceServiceProvider);
  return service.getNextType(userId, store.id);
});

/// Attendance history (last 7 days)
final attendanceHistoryProvider =
    FutureProvider.family<List<Attendance>, String>((ref, storeId) {
  final db = ref.watch(databaseProvider);
  return db.attendanceDao.getHistory(storeId);
});
