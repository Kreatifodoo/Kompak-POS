import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../services/combo_service.dart';
import '../core_providers.dart';

/// Watch combo groups for a specific product
final comboGroupsProvider =
    StreamProvider.family<List<ComboGroup>, String>((ref, productId) {
  final service = ref.watch(comboServiceProvider);
  return service.watchGroupsByProduct(productId);
});

/// Watch items in a specific combo group
final comboGroupItemsProvider =
    StreamProvider.family<List<ComboGroupItem>, String>((ref, groupId) {
  final service = ref.watch(comboServiceProvider);
  return service.watchItemsByGroup(groupId);
});

/// Get full combo configuration (groups + items with product info) for POS
final comboConfigProvider =
    FutureProvider.family<List<ComboGroupWithItems>, String>(
        (ref, productId) async {
  final service = ref.watch(comboServiceProvider);
  return service.getComboConfig(productId);
});
