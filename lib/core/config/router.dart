import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import all screens
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/pos/catalog/catalog_screen.dart';
import '../../screens/pos/catalog/product_detail_screen.dart';
import '../../screens/pos/cart/cart_screen.dart';
import '../../screens/pos/payment/payment_screen.dart';
import '../../screens/pos/receipt/receipt_screen.dart';
import '../../screens/pos/barcode/barcode_scanner_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../screens/kitchen/kitchen_display_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/inventory/inventory_detail_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/settings/printer_settings_screen.dart';
import '../../screens/settings/store_settings_screen.dart';
import '../../screens/settings/sync_status_screen.dart';
import '../../screens/master/product_list_screen.dart';
import '../../screens/master/product_form_screen.dart';
import '../../screens/master/category_list_screen.dart';
import '../../screens/master/user_list_screen.dart';
import '../../screens/master/user_form_screen.dart';
import '../../screens/master/customer_list_screen.dart';
import '../../screens/master/customer_form_screen.dart';
import '../../screens/master/payment_method_list_screen.dart';
import '../../screens/master/payment_method_form_screen.dart';
import '../../screens/master/pricelist_list_screen.dart';
import '../../screens/master/pricelist_form_screen.dart';
import '../../screens/master/charge_list_screen.dart';
import '../../screens/master/charge_form_screen.dart';
import '../../screens/master/promotion_list_screen.dart';
import '../../screens/master/promotion_form_screen.dart';
import '../../screens/master/combo_config_screen.dart';
import '../../screens/master/bom_config_screen.dart';
import '../../screens/master/terminal_list_screen.dart';
import '../../screens/master/terminal_form_screen.dart';
import '../../screens/reports/session_report_screen.dart';
import '../../screens/reports/sales_report_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../modules/auth/auth_providers.dart';
import '../../screens/inventory/restock_screen.dart';
import '../../screens/inventory/adjustment_screen.dart';
import '../../screens/inventory/inventory_report_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final user = ref.read(currentUserProvider);
      final isAuthRoute = state.matchedLocation == '/' || state.matchedLocation == '/auth';
      if (user == null && !isAuthRoute) return '/auth';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/pos/catalog', builder: (_, __) => const CatalogScreen()),
      GoRoute(
        path: '/pos/catalog/:id',
        builder: (_, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/pos/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/pos/payment', builder: (_, __) => const PaymentScreen()),
      GoRoute(
        path: '/pos/receipt/:orderId',
        builder: (_, state) => ReceiptScreen(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(path: '/pos/barcode', builder: (_, __) => const BarcodeScannerScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/kitchen', builder: (_, __) => const KitchenDisplayScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/inventory/restock', builder: (_, __) => const RestockScreen()),
      GoRoute(path: '/inventory/adjustment', builder: (_, __) => const AdjustmentScreen()),
      GoRoute(path: '/inventory/report', builder: (_, __) => const InventoryReportScreen()),
      GoRoute(
        path: '/inventory/:productId',
        builder: (_, state) => InventoryDetailScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/settings/printer', builder: (_, __) => const PrinterSettingsScreen()),
      GoRoute(path: '/settings/store', builder: (_, __) => const StoreSettingsScreen()),
      GoRoute(path: '/settings/sync', builder: (_, __) => const SyncStatusScreen()),
      // Master data routes
      GoRoute(path: '/settings/products', builder: (_, __) => const ProductListScreen()),
      GoRoute(path: '/settings/products/new', builder: (_, __) => const ProductFormScreen()),
      GoRoute(
        path: '/settings/products/:id/edit',
        builder: (_, state) => ProductFormScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(path: '/settings/categories', builder: (_, __) => const CategoryListScreen()),
      GoRoute(path: '/settings/users', builder: (_, __) => const UserListScreen()),
      GoRoute(path: '/settings/users/new', builder: (_, __) => const UserFormScreen()),
      GoRoute(
        path: '/settings/users/:id/edit',
        builder: (_, state) => UserFormScreen(userId: state.pathParameters['id']),
      ),
      GoRoute(path: '/settings/customers', builder: (_, __) => const CustomerListScreen()),
      GoRoute(path: '/settings/customers/new', builder: (_, __) => const CustomerFormScreen()),
      GoRoute(
        path: '/settings/customers/:id/edit',
        builder: (_, state) => CustomerFormScreen(customerId: state.pathParameters['id']),
      ),
      GoRoute(path: '/settings/payment-methods', builder: (_, __) => const PaymentMethodListScreen()),
      GoRoute(path: '/settings/payment-methods/new', builder: (_, __) => const PaymentMethodFormScreen()),
      GoRoute(
        path: '/settings/payment-methods/:id/edit',
        builder: (_, state) => PaymentMethodFormScreen(paymentMethodId: state.pathParameters['id']),
      ),
      GoRoute(path: '/settings/pricelists', builder: (_, __) => const PricelistListScreen()),
      GoRoute(path: '/settings/pricelists/new', builder: (_, __) => const PricelistFormScreen()),
      GoRoute(
        path: '/settings/pricelists/:id/edit',
        builder: (_, state) => PricelistFormScreen(pricelistId: state.pathParameters['id']),
      ),
      GoRoute(path: '/settings/charges', builder: (_, __) => const ChargeListScreen()),
      GoRoute(path: '/settings/charges/new', builder: (_, __) => const ChargeFormScreen()),
      GoRoute(
        path: '/settings/charges/:id/edit',
        builder: (_, state) => ChargeFormScreen(chargeId: state.pathParameters['id']),
      ),
      GoRoute(path: '/settings/promotions', builder: (_, __) => const PromotionListScreen()),
      GoRoute(path: '/settings/promotions/new', builder: (_, __) => const PromotionFormScreen()),
      GoRoute(
        path: '/settings/promotions/:id/edit',
        builder: (_, state) => PromotionFormScreen(promotionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/settings/products/:id/combo',
        builder: (_, state) => ComboConfigScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings/products/:id/bom',
        builder: (_, state) => BomConfigScreen(productId: state.pathParameters['id']!),
      ),
      // Terminal management
      GoRoute(path: '/settings/terminals', builder: (_, __) => const TerminalListScreen()),
      GoRoute(path: '/settings/terminals/new', builder: (_, __) => const TerminalFormScreen()),
      GoRoute(
        path: '/settings/terminals/:id',
        builder: (_, state) => TerminalFormScreen(terminalId: state.pathParameters['id']),
      ),
      // Reports
      GoRoute(path: '/reports/sessions', builder: (_, __) => const SessionReportListScreen()),
      GoRoute(
        path: '/reports/sessions/:id',
        builder: (_, state) => SessionReportDetailScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/reports/sales', builder: (_, __) => const SalesReportScreen()),
      // Keep old routes for settings access
      GoRoute(path: '/settings/reports/sessions', builder: (_, __) => const SessionReportListScreen()),
      GoRoute(
        path: '/settings/reports/sessions/:id',
        builder: (_, state) => SessionReportDetailScreen(sessionId: state.pathParameters['id']!),
      ),
    ],
  );
});
