import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../services/bom_service.dart';

/// Watch BOM items for a specific product (reactive stream)
final bomItemsProvider =
    StreamProvider.family<List<BomItem>, String>((ref, productId) {
  final service = ref.watch(bomServiceProvider);
  return service.watchItemsByProduct(productId);
});

/// Get full BOM configuration (items with product info) for display
final bomConfigProvider =
    FutureProvider.family<List<BomItemWithProduct>, String>(
        (ref, productId) async {
  final service = ref.watch(bomServiceProvider);
  return service.getBomConfig(productId);
});
