import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/users_table.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  Future<List<User>> getAllUsers() => select(users).get();

  Future<List<User>> getUsersByStore(String storeId) =>
      (select(users)..where((u) => u.storeId.equals(storeId))).get();

  Future<User?> getUserById(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<User?> authenticateByPin(String pin) =>
      (select(users)
            ..where((u) => u.pin.equals(pin) & u.isActive.equals(true)))
          .getSingleOrNull();

  Future<int> insertUser(UsersCompanion user) =>
      into(users).insert(user);

  Future<bool> updateUser(UsersCompanion user) =>
      update(users).replace(user);

  Future<int> deleteUser(String id) =>
      (delete(users)..where((u) => u.id.equals(id))).go();

  Stream<List<User>> watchUsersByStore(String storeId) =>
      (select(users)..where((u) => u.storeId.equals(storeId))).watch();
}
