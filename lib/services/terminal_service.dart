import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class TerminalService {
  final AppDatabase db;
  static const _uuid = Uuid();

  TerminalService(this.db);

  // ── Query ──

  Future<List<Terminal>> getByStore(String storeId) =>
      db.terminalDao.getByStore(storeId);

  Stream<List<Terminal>> watchByStore(String storeId) =>
      db.terminalDao.watchByStore(storeId);

  Future<List<Terminal>> getActiveByStore(String storeId) =>
      db.terminalDao.getActiveByStore(storeId);

  Future<Terminal?> getById(String id) => db.terminalDao.getById(id);

  // ── CRUD ──

  Future<String> createTerminal({
    required String storeId,
    required String name,
    required String code,
  }) async {
    final id = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: id,
      storeId: storeId,
      name: name,
      code: code,
    ));
    return id;
  }

  Future<void> updateTerminal({
    required String id,
    required String storeId,
    required String name,
    required String code,
    bool isActive = true,
    String? printerAddress,
    String? printerName,
  }) async {
    await db.terminalDao.updateTerminal(TerminalsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      code: Value(code),
      isActive: Value(isActive),
      printerAddress: Value(printerAddress),
      printerName: Value(printerName),
    ));
  }

  Future<void> deleteTerminal(String id) async {
    await db.terminalDao.deleteTerminal(id);
  }

  // ── Printer ──

  Future<void> savePrinterToTerminal(
    String terminalId,
    String? address,
    String? name,
  ) async {
    final terminal = await db.terminalDao.getById(terminalId);
    if (terminal != null) {
      await db.terminalDao.updateTerminal(TerminalsCompanion(
        id: Value(terminal.id),
        storeId: Value(terminal.storeId),
        name: Value(terminal.name),
        code: Value(terminal.code),
        isActive: Value(terminal.isActive),
        printerAddress: Value(address),
        printerName: Value(name),
        createdAt: Value(terminal.createdAt),
      ));
    }
  }
}
