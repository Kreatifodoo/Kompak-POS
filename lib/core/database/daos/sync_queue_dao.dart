import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<List<SyncQueueData>> getPending({int limit = 50}) =>
      (select(syncQueue)
            ..where((s) => s.status.equals('pending'))
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])
            ..limit(limit))
          .get();

  Stream<int> watchPendingCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.status.equals('pending'));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<int> enqueue({
    required String targetTable,
    required String recordId,
    required String operation,
    required String payload,
  }) =>
      into(syncQueue).insert(SyncQueueCompanion.insert(
        targetTable: targetTable,
        recordId: recordId,
        operation: operation,
        payload: payload,
      ));

  Future<void> markSynced(int id) =>
      (update(syncQueue)..where((s) => s.id.equals(id))).write(
        SyncQueueCompanion(
          status: const Value('synced'),
          syncedAt: Value(DateTime.now()),
        ),
      );

  Future<void> markFailed(int id) async {
    final entry = await (select(syncQueue)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    if (entry != null) {
      await (update(syncQueue)..where((s) => s.id.equals(id))).write(
        SyncQueueCompanion(
          status: const Value('failed'),
          retryCount: Value(entry.retryCount + 1),
        ),
      );
    }
  }

  Future<int> deleteOldSynced({int daysOld = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    return (delete(syncQueue)
          ..where((s) =>
              s.status.equals('synced') &
              s.syncedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// BUG-SIT-003 FIX: Delete failed items that have exceeded max retries or
  /// are older than [daysOld] days to prevent unbounded table growth when
  /// the backend is unreachable.
  Future<int> deleteOldFailed({int daysOld = 30, int maxRetries = 10}) {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    return customStatement(
      'DELETE FROM sync_queue WHERE status = ? AND (retry_count >= ? OR created_at < ?)',
      ['failed', maxRetries, cutoff.toIso8601String()],
    ).then((_) => 0);
  }
}
