import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class CustomerService {
  final AppDatabase db;
  static const _uuid = Uuid();

  CustomerService(this.db);

  Future<List<Customer>> getAllByStore(String storeId) =>
      db.customerDao.getAllByStore(storeId);

  Stream<List<Customer>> watchAllByStore(String storeId) =>
      db.customerDao.watchAllByStore(storeId);

  Future<List<Customer>> searchCustomers(String storeId, String query) =>
      db.customerDao.searchCustomers(storeId, query);

  Future<Customer?> getById(String id) => db.customerDao.getById(id);

  Future<String> createCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? email,
  }) async {
    final id = _uuid.v4();
    await db.customerDao.insertCustomer(CustomersCompanion.insert(
      id: id,
      storeId: storeId,
      name: name,
      phone: Value(phone),
      email: Value(email),
    ));
    return id;
  }

  Future<void> updateCustomer({
    required String id,
    required String storeId,
    required String name,
    String? phone,
    String? email,
    int points = 0,
  }) async {
    await db.customerDao.updateCustomer(CustomersCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      phone: Value(phone),
      email: Value(email),
      points: Value(points),
    ));
  }

  Future<void> deleteCustomer(String id) async {
    await db.customerDao.deleteCustomer(id);
  }
}
