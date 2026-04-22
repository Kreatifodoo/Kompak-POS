// SIT: Auth Login → Logout → Re-login Flow
// Tests the login/logout/re-login bug (BUG-AUTH-001, BUG-AUTH-002)
// Root cause: FutureProvider.family caches result per PIN — after logout,
// re-login with the same PIN returned cached result without re-running
// the provider body → providers not re-set → infinite loading spinner.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kompak_pos/core/database/app_database.dart';
import 'package:kompak_pos/services/auth_service.dart';
import 'package:kompak_pos/core/utils/pin_hash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

// Minimal in-memory AuthService using a real DB + in-memory SharedPreferences
Future<AuthService> _buildAuthService(AppDatabase db) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AuthService(db: db, prefs: prefs);
}

Future<String> _seedStore(AppDatabase db) async {
  const uuid = Uuid();
  final storeId = uuid.v4();
  await db.storeDao.insertStore(StoresCompanion.insert(
    id: storeId,
    name: 'Test Store',
  ));
  return storeId;
}

Future<String> _seedTerminal(AppDatabase db, String storeId) async {
  const uuid = Uuid();
  final terminalId = uuid.v4();
  await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
    id: terminalId,
    storeId: storeId,
    name: 'Kasir 1',
    code: 'T1',
  ));
  return terminalId;
}

Future<String> _seedUser(
  AppDatabase db, {
  required String storeId,
  required String terminalId,
  required String pin,
  String role = 'cashier',
}) async {
  const uuid = Uuid();
  final userId = uuid.v4();
  await db.userDao.insertUser(UsersCompanion.insert(
    id: userId,
    name: 'Test Cashier',
    pin: PinHash.hash(pin),
    role: Value(role),
    storeId: Value(storeId),
    terminalId: Value(terminalId),
  ));
  return userId;
}

void main() {
  group('AUTH-FLOW: Login → Logout → Re-login', () {
    late AppDatabase db;
    late AuthService authService;
    late String storeId;
    late String terminalId;
    late String userId;
    const pin = '123456';

    setUp(() async {
      db = _openDb();
      authService = await _buildAuthService(db);
      storeId = await _seedStore(db);
      terminalId = await _seedTerminal(db, storeId);
      userId = await _seedUser(db,
          storeId: storeId, terminalId: terminalId, pin: pin);
    });

    tearDown(() => db.close());

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-001: First login succeeds
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-001: First login with correct PIN returns user', () async {
      final user = await authService.authenticateByPin(pin);

      expect(user, isNotNull);
      expect(user!.id, equals(userId));
      expect(user.storeId, equals(storeId));
      expect(user.terminalId, equals(terminalId));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-002: saveSession persists userId and terminalId
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-002: saveSession stores userId + terminalId', () async {
      final user = (await authService.authenticateByPin(pin))!;
      await authService.saveSession(user.id, terminalId: user.terminalId);
      await authService.setCurrentStoreId(storeId);

      final restoredUser = await authService.getCurrentUser();
      final restoredStoreId = await authService.getCurrentStoreId();
      final restoredTerminalId = authService.getCurrentTerminalId();

      expect(restoredUser?.id, equals(userId));
      expect(restoredStoreId, equals(storeId));
      expect(restoredTerminalId, equals(terminalId));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-003: clearSession removes all stored keys
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-003: clearSession removes all stored session data', () async {
      final user = (await authService.authenticateByPin(pin))!;
      await authService.saveSession(user.id, terminalId: user.terminalId);
      await authService.setCurrentStoreId(storeId);

      // Verify stored
      expect(await authService.getCurrentUser(), isNotNull);
      expect(await authService.getCurrentStoreId(), isNotNull);
      expect(authService.getCurrentTerminalId(), isNotNull);

      // Logout
      await authService.clearSession();

      // Verify cleared
      expect(await authService.getCurrentUser(), isNull,
          reason: 'userId should be removed');
      expect(await authService.getCurrentStoreId(), isNull,
          reason: 'storeId should be removed');
      expect(authService.getCurrentTerminalId(), isNull,
          reason: 'terminalId should be removed');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-004 (BUG-AUTH-001): Re-login with same PIN after logout
    // authenticateByPin must work again — verifies the DB layer still finds user
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-004: Re-login with same PIN after logout still authenticates', () async {
      // First login
      final user1 = await authService.authenticateByPin(pin);
      expect(user1, isNotNull, reason: 'First login should succeed');
      await authService.saveSession(user1!.id, terminalId: user1.terminalId);

      // Logout
      await authService.clearSession();
      expect(await authService.getCurrentUser(), isNull,
          reason: 'Should be logged out');

      // Re-login with same PIN — BUG-AUTH-001: cached FutureProvider would
      // skip re-running authenticateByPin and not re-set providers.
      // At the service layer this must always return the user.
      final user2 = await authService.authenticateByPin(pin);
      expect(user2, isNotNull,
          reason: 'Re-login with same PIN must succeed after logout');
      expect(user2!.id, equals(userId),
          reason: 'Should return the same user');

      // Save session again (as authenticateProvider body does)
      await authService.saveSession(user2.id, terminalId: user2.terminalId);
      await authService.setCurrentStoreId(storeId);

      final restored = await authService.getCurrentUser();
      expect(restored?.id, equals(userId),
          reason: 'Session should be persisted after re-login');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-005: Login → Logout → Login → Logout cycle (3x)
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-005: Login/logout cycle works 3 times in a row', () async {
      for (int i = 1; i <= 3; i++) {
        final user = await authService.authenticateByPin(pin);
        expect(user, isNotNull, reason: 'Login attempt $i should succeed');

        await authService.saveSession(user!.id, terminalId: user.terminalId);
        await authService.setCurrentStoreId(storeId);

        final restored = await authService.getCurrentUser();
        expect(restored, isNotNull, reason: 'Session $i should be restorable');

        await authService.clearSession();
        expect(await authService.getCurrentUser(), isNull,
            reason: 'Session $i should be cleared after logout');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-006: Wrong PIN after logout returns null (no ghost auth)
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-006: Wrong PIN after logout returns null', () async {
      // Login + logout
      final user = (await authService.authenticateByPin(pin))!;
      await authService.saveSession(user.id, terminalId: user.terminalId);
      await authService.clearSession();

      // Try wrong PIN
      final result = await authService.authenticateByPin('000000');
      expect(result, isNull,
          reason: 'Wrong PIN should not authenticate after logout');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-007: Terminal storeId is used after login (STRUCT-004)
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-007: Authenticated user has correct storeId via terminal', () async {
      final user = await authService.authenticateByPin(pin);
      expect(user, isNotNull);

      // Simulate auth provider logic: derive storeId from terminal
      final terminal = await db.terminalDao.getById(user!.terminalId!);
      final effectiveStoreId = terminal?.storeId ?? user.storeId;

      expect(effectiveStoreId, equals(storeId),
          reason: 'storeId must match terminal.storeId (STRUCT-004 fix)');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AUTH-FLOW-008: Owner without terminal — storeId from user.storeId
    // ─────────────────────────────────────────────────────────────────────────
    test('AUTH-FLOW-008: Owner login without terminal uses user.storeId', () async {
      const ownerPin = '999999';
      final ownerId = const Uuid().v4();
      await db.userDao.insertUser(UsersCompanion.insert(
        id: ownerId,
        name: 'Owner',
        pin: PinHash.hash(ownerPin),
        role: Value('owner'),
        storeId: Value(storeId),
        terminalId: const Value(null),
      ));

      final user = await authService.authenticateByPin(ownerPin);
      expect(user, isNotNull);
      expect(user!.terminalId, isNull);

      // Simulate auth provider: no terminal → use user.storeId
      final terminal = user.terminalId != null
          ? await db.terminalDao.getById(user.terminalId!)
          : null;
      final effectiveStoreId = terminal?.storeId ?? user.storeId;

      expect(effectiveStoreId, equals(storeId));
    });
  });
}
