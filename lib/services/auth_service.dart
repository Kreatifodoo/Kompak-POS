import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/storage_keys.dart';
import '../core/database/app_database.dart';
import '../core/utils/pin_hash.dart';

class AuthService {
  final AppDatabase db;
  final SharedPreferences prefs;

  AuthService({required this.db, required this.prefs});

  Future<User?> authenticateByPin(String pin) async {
    final hashedPin = PinHash.hash(pin);
    return await db.userDao.authenticateByPin(hashedPin);
  }

  Future<void> saveSession(String userId, {String? terminalId}) async {
    await prefs.setString(StorageKeys.currentUserId, userId);
    if (terminalId != null) {
      await prefs.setString(StorageKeys.currentTerminalId, terminalId);
    }
  }

  Future<void> clearSession() async {
    await prefs.remove(StorageKeys.currentUserId);
    await prefs.remove(StorageKeys.currentStoreId);
    await prefs.remove(StorageKeys.currentTerminalId);
  }

  Future<User?> getCurrentUser() async {
    final userId = prefs.getString(StorageKeys.currentUserId);
    if (userId == null) return null;
    return await db.userDao.getUserById(userId);
  }

  Future<String?> getCurrentStoreId() async {
    return prefs.getString(StorageKeys.currentStoreId);
  }

  Future<void> setCurrentStoreId(String storeId) async {
    await prefs.setString(StorageKeys.currentStoreId, storeId);
  }

  String? getCurrentTerminalId() {
    return prefs.getString(StorageKeys.currentTerminalId);
  }

  Future<void> setCurrentTerminalId(String terminalId) async {
    await prefs.setString(StorageKeys.currentTerminalId, terminalId);
  }
}
