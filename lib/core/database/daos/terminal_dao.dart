import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/terminals_table.dart';

part 'terminal_dao.g.dart';

@DriftAccessor(tables: [Terminals])
class TerminalDao extends DatabaseAccessor<AppDatabase>
    with _$TerminalDaoMixin {
  TerminalDao(super.db);

  /// Get all terminals for a store
  Future<List<Terminal>> getByStore(String storeId) =>
      (select(terminals)
            ..where((t) => t.storeId.equals(storeId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  /// Watch all terminals for a store (reactive stream)
  Stream<List<Terminal>> watchByStore(String storeId) =>
      (select(terminals)
            ..where((t) => t.storeId.equals(storeId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  /// Get active terminals for a store
  Future<List<Terminal>> getActiveByStore(String storeId) =>
      (select(terminals)
            ..where(
                (t) => t.storeId.equals(storeId) & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  /// Get a single terminal by ID
  Future<Terminal?> getById(String id) =>
      (select(terminals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTerminal(TerminalsCompanion terminal) =>
      into(terminals).insert(terminal);

  Future<bool> updateTerminal(TerminalsCompanion terminal) =>
      update(terminals).replace(terminal);

  Future<int> deleteTerminal(String id) =>
      (delete(terminals)..where((t) => t.id.equals(id))).go();
}
