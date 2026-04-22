import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../core/utils/pin_hash.dart';

class UserService {
  final AppDatabase db;
  static const _uuid = Uuid();

  UserService(this.db);

  Future<List<User>> getUsersByStore(String storeId) =>
      db.userDao.getUsersByStore(storeId);

  Stream<List<User>> watchUsersByStore(String storeId) =>
      db.userDao.watchUsersByStore(storeId);

  Future<User?> getUserById(String id) => db.userDao.getUserById(id);

  Future<String> createUser({
    required String name,
    required String pin,
    required String role,
    String? storeId,
    String? terminalId,
    bool canAccessAttendance = false,
  }) async {
    final id = _uuid.v4();
    final hashedPin = PinHash.hash(pin);
    await db.userDao.insertUser(UsersCompanion.insert(
      id: id,
      name: name,
      pin: hashedPin,
      role: Value(role),
      storeId: Value(storeId),
      terminalId: Value(terminalId),
      canAccessAttendance: Value(canAccessAttendance),
    ));
    return id;
  }

  Future<void> updateUser({
    required String id,
    required String name,
    String? pin,
    required String role,
    String? storeId,
    String? terminalId,
    bool isActive = true,
    bool? canAccessAttendance,
  }) async {
    // If pin is null or empty, keep the existing PIN
    String? finalPin;
    if (pin != null && pin.isNotEmpty) {
      finalPin = PinHash.hash(pin);
    }

    final user = await db.userDao.getUserById(id);
    if (user == null) return;

    await db.userDao.updateUser(UsersCompanion(
      id: Value(id),
      name: Value(name),
      pin: Value(finalPin ?? user.pin),
      role: Value(role),
      storeId: Value(storeId),
      terminalId: Value(terminalId),
      isActive: Value(isActive),
      canAccessAttendance:
          Value(canAccessAttendance ?? user.canAccessAttendance),
    ));
  }

  Future<void> deactivateUser(String id) async {
    final user = await db.userDao.getUserById(id);
    if (user != null) {
      await db.userDao.updateUser(UsersCompanion(
        id: Value(user.id),
        name: Value(user.name),
        pin: Value(user.pin),
        isActive: const Value(false),
      ));
    }
  }

  Future<bool> isPinUnique(String pin, {String? excludeUserId}) async {
    final hashedPin = PinHash.hash(pin);
    final existing = await db.userDao.authenticateByPin(hashedPin);
    if (existing == null) return true;
    if (excludeUserId != null && existing.id == excludeUserId) return true;
    return false;
  }
}
