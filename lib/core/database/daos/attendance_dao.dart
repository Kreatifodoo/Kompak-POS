import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/attendances_table.dart';

part 'attendance_dao.g.dart';

@DriftAccessor(tables: [Attendances])
class AttendanceDao extends DatabaseAccessor<AppDatabase>
    with _$AttendanceDaoMixin {
  AttendanceDao(super.db);

  Future<void> insertAttendance(AttendancesCompanion entry) =>
      into(attendances).insert(entry);

  /// Get attendance records for a date range (for reporting)
  Future<List<Attendance>> getByDateRange(
    String storeId,
    DateTime start,
    DateTime end,
  ) =>
      (select(attendances)
            ..where((a) =>
                a.storeId.equals(storeId) &
                a.timestamp.isBiggerOrEqualValue(start) &
                a.timestamp.isSmallerThanValue(end))
            ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
          .get();

  /// Get unsent attendance records for Telegram delivery
  Future<List<Attendance>> getUnsent() =>
      (select(attendances)
            ..where((a) => a.telegramSent.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.timestamp)]))
          .get();

  /// Mark a record as sent to Telegram
  Future<void> markSent(String id) =>
      (update(attendances)..where((a) => a.id.equals(id))).write(
        const AttendancesCompanion(telegramSent: Value(true)),
      );

  /// Get the most recent attendance for a user (for time validation)
  Future<Attendance?> getLastAttendance(String userId) =>
      (select(attendances)
            ..where((a) => a.userId.equals(userId))
            ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
            ..limit(1))
          .getSingleOrNull();

  /// Get today's attendance records for a user at a store
  Future<List<Attendance>> getTodayAttendance(
    String userId,
    String storeId,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(attendances)
          ..where((a) =>
              a.userId.equals(userId) &
              a.storeId.equals(storeId) &
              a.timestamp.isBiggerOrEqualValue(startOfDay) &
              a.timestamp.isSmallerThanValue(endOfDay))
          ..orderBy([(a) => OrderingTerm.asc(a.timestamp)]))
        .get();
  }

  /// Watch today's attendance (reactive)
  Stream<List<Attendance>> watchTodayAttendance(
    String userId,
    String storeId,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(attendances)
          ..where((a) =>
              a.userId.equals(userId) &
              a.storeId.equals(storeId) &
              a.timestamp.isBiggerOrEqualValue(startOfDay) &
              a.timestamp.isSmallerThanValue(endOfDay))
          ..orderBy([(a) => OrderingTerm.asc(a.timestamp)]))
        .watch();
  }

  /// Get records older than cutoff (for cleanup — returns photo paths)
  Future<List<Attendance>> getOlderThan(DateTime cutoff) =>
      (select(attendances)..where((a) => a.timestamp.isSmallerThanValue(cutoff)))
          .get();

  /// Delete records older than cutoff
  Future<int> deleteOlderThan(DateTime cutoff) =>
      (delete(attendances)
            ..where((a) => a.timestamp.isSmallerThanValue(cutoff)))
          .go();

  /// Get attendance history (last N days)
  Future<List<Attendance>> getHistory(String storeId, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(attendances)
          ..where((a) =>
              a.storeId.equals(storeId) &
              a.timestamp.isBiggerOrEqualValue(cutoff))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .get();
  }
}
