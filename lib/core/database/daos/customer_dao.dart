import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/customers_table.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers])
class CustomerDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerDaoMixin {
  CustomerDao(super.db);

  Future<List<Customer>> getAllByStore(String storeId) =>
      (select(customers)..where((c) => c.storeId.equals(storeId))).get();

  Future<List<Customer>> searchCustomers(String storeId, String query) =>
      (select(customers)
            ..where((c) =>
                c.storeId.equals(storeId) &
                (c.name.like('%$query%') | c.phone.like('%$query%'))))
          .get();

  Future<Customer?> getById(String id) =>
      (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);

  Future<bool> updateCustomer(CustomersCompanion customer) =>
      update(customers).replace(customer);

  Future<int> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  Stream<List<Customer>> watchAllByStore(String storeId) =>
      (select(customers)..where((c) => c.storeId.equals(storeId))).watch();
}
