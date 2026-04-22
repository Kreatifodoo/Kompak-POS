import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/database/app_database.dart';
import '../../../models/cart_item_model.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/product/product_providers.dart';
import '../../../modules/pos/cart_providers.dart';
import '../../../modules/pricelist/pricelist_providers.dart';
import '../../../modules/auth/auth_providers.dart';
import '../../../modules/pos_session/pos_session_providers.dart';
import '../combo/combo_selection_sheet.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../session/open_register_screen.dart';
import '../session/close_register_dialog.dart';
import '../cart/cart_panel.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  // ── Bluetooth HID scanner support ──────────────────────────────────────────
  // BT scanners inject keyboard events very rapidly and end with Enter.
  // We buffer the characters and process on Enter key.
  final StringBuffer _btScanBuffer = StringBuffer();
  DateTime _lastScanKeyTime = DateTime(2000);
  static const _btScanTimeoutMs = 100; // chars < 100ms apart = scanner input

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    // Start Telegram chatbot polling if enabled
    _startChatbotIfEnabled();
    // Keep screen on so POS device stays active & bot keeps responding
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _searchController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enable wakelock (OS may have released it)
      WakelockPlus.enable();
      // Ensure chatbot polling is running
      final chatbot = ref.read(telegramChatbotServiceProvider);
      if (chatbot.isEnabled && !chatbot.isPolling) {
        chatbot.startPolling();
        chatbot.sendStatusNotification(online: true);
      }
    }
    // NOTE: We intentionally do NOT stop polling on paused.
    // The bot should keep responding even when screen is off / app backgrounded.
  }

  void _startChatbotIfEnabled() {
    final chatbot = ref.read(telegramChatbotServiceProvider);
    if (chatbot.isEnabled && !chatbot.isPolling) {
      chatbot.startPolling();
    }
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Only intercept when no text field is explicitly focused (avoids stealing
    // input from search bar, forms, dialogs, etc.)
    final focusedWidget = FocusManager.instance.primaryFocus;
    if (focusedWidget != null &&
        focusedWidget.context != null &&
        focusedWidget.context!.widget is EditableText) {
      return false; // let normal text field handle it
    }

    final now = DateTime.now();
    final gap = now.difference(_lastScanKeyTime).inMilliseconds;

    // Enter key = end of scan sequence
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final scanned = _btScanBuffer.toString().trim();
      _btScanBuffer.clear();
      if (scanned.isNotEmpty) {
        _handleBtScanResult(scanned);
        return true;
      }
      return false;
    }

    // If gap > timeout and buffer is non-empty, previous scan was incomplete — reset
    if (gap > _btScanTimeoutMs * 5 && _btScanBuffer.isNotEmpty) {
      _btScanBuffer.clear();
    }

    _lastScanKeyTime = now;

    // Append printable characters only
    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _btScanBuffer.write(char);
      return true; // consume the key event so it doesn't pollute the search bar
    }

    return false;
  }

  Future<void> _handleBtScanResult(String barcode) async {
    try {
      final service = ref.read(productServiceProvider);
      final product = await service.findByBarcode(barcode);
      if (!mounted) return;
      if (product != null) {
        final cartItem = CartItem(
          productId: product.id,
          productName: product.name,
          productPrice: product.price,
          quantity: 1,
          lineTotal: product.price,
          imageUrl: product.imageUrl,
        );
        ref.read(cartProvider.notifier).addItem(cartItem);
        context.showSnackBar('${product.name} ditambahkan ke keranjang');
      } else {
        context.showSnackBar('Produk tidak ditemukan: $barcode', isError: true);
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Scan error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) return const OpenRegisterScreen();
        return _buildCatalog(context, session);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildCatalog(context, null),
    );
  }

  /// Check if the screen is wide enough for split layout (web desktop)
  bool _isWideScreen(BuildContext context) =>
      kIsWeb && MediaQuery.of(context).size.width >= 900;

  Widget _buildCatalog(BuildContext context, PosSession? session) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(filteredProductsProvider);
    final cart = ref.watch(cartProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isWide = _isWideScreen(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.watch(currentStoreProvider)?.name ?? 'Kompak Store',
              style: AppTextStyles.heading3.copyWith(fontSize: 16),
            ),
            Text(
              session != null
                  ? 'Session aktif sejak ${Formatters.time(session.openedAt)}'
                  : 'Ready to serve',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.successGreen,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.errorRed),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context, session),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: _buildDrawer(context, session),
      body: isWide
          ? _buildWebSplitLayout(categoriesAsync, productsAsync, selectedCategory)
          : Column(
              children: [
                _buildSearchBar(),
                _buildCategoryBar(categoriesAsync, selectedCategory),
                Expanded(child: _buildProductGrid(productsAsync)),
              ],
            ),
      // Cart bottom bar — only on mobile
      bottomNavigationBar:
          !isWide && cart.isNotEmpty ? _buildCartBottomBar(cart) : null,
      // Barcode FAB — only on mobile
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/pos/barcode'),
              backgroundColor: AppColors.primaryOrange,
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white),
            ),
    );
  }

  /// Web split layout: products left (≈62%), cart right (≈38%)
  Widget _buildWebSplitLayout(
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Product>> productsAsync,
    String? selectedCategory,
  ) {
    return Row(
      children: [
        // Left — product catalog
        Expanded(
          flex: 62,
          child: Column(
            children: [
              _buildSearchBar(),
              _buildCategoryBar(categoriesAsync, selectedCategory),
              Expanded(child: _buildWebProductGrid(productsAsync)),
            ],
          ),
        ),
        // Right — cart panel
        const Expanded(
          flex: 38,
          child: CartPanel(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          ref.read(searchQueryProvider.notifier).state = value;
        },
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.textHint),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar(
    AsyncValue<List<Category>> categoriesAsync,
    String? selectedCategory,
  ) {
    return SizedBox(
      height: 48,
      child: categoriesAsync.when(
        data: (categories) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildCategoryChip(
                  label: 'All',
                  isSelected: selectedCategory == null,
                  onTap: () {
                    ref.read(selectedCategoryProvider.notifier).state = null;
                  },
                );
              }
              final category = categories[index - 1];
              return _buildCategoryChip(
                label: category.name,
                isSelected: selectedCategory == category.id,
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state = category.id;
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load categories')),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          backgroundColor: isSelected ? AppColors.chipSelected : AppColors.chipUnselected,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
    );
  }

  Widget _buildProductGrid(AsyncValue<List<Product>> productsAsync) {
    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppColors.textHint.withOpacity(0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No products found',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load products',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorRed),
        ),
      ),
    );
  }

  /// Web product grid — responsive columns based on available width, compact cards
  Widget _buildWebProductGrid(AsyncValue<List<Product>> productsAsync) {
    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppColors.textHint.withOpacity(0.5)),
                const SizedBox(height: AppSpacing.sm),
                Text('No products found',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textHint)),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            // Calculate columns based on available width
            final cols = (constraints.maxWidth / 180).floor().clamp(3, 6);
            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                childAspectRatio: 0.82,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  _buildWebProductCard(products[index]),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text('Failed to load products',
            style:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.errorRed)),
      ),
    );
  }

  /// Compact product card for web split layout
  Widget _buildWebProductCard(Product product) {
    return GestureDetector(
      onTap: () async {
        if (product.isCombo) {
          final result = await showModalBottomSheet<CartItem>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ComboSelectionSheet(comboProduct: product),
          );
          if (result != null && context.mounted) {
            ref.read(cartProvider.notifier).addItem(result);
            context.showSnackBar('${product.name} added to cart');
          }
        } else {
          final cartItem = CartItem(
            productId: product.id,
            productName: product.name,
            productPrice: product.price,
            quantity: 1,
            lineTotal: product.price,
            imageUrl: product.imageUrl,
          );
          ref.read(cartProvider.notifier).addItem(cartItem);
          context.showSnackBar('${product.name} added to cart');
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10)),
                      ),
                      child: product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10)),
                              child: _buildProductImage(product.imageUrl!),
                            )
                          : _buildPlaceholderIcon(),
                    ),
                    if (product.isCombo)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.infoBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'COMBO',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Info area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      _buildPriceDisplay(product),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => context.push('/pos/catalog/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: _buildProductImage(product.imageUrl!),
                          )
                        : _buildPlaceholderIcon(),
                  ),
                  if (product.isCombo)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.infoBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'COMBO',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildPriceDisplay(product),
                        ),
                        // Quick add button
                        GestureDetector(
                          onTap: () async {
                            if (product.isCombo) {
                              final result = await showModalBottomSheet<CartItem>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ComboSelectionSheet(
                                    comboProduct: product),
                              );
                              if (result != null && context.mounted) {
                                ref.read(cartProvider.notifier).addItem(result);
                                context.showSnackBar('${product.name} added to cart');
                              }
                            } else {
                              final cartItem = CartItem(
                                productId: product.id,
                                productName: product.name,
                                productPrice: product.price,
                                quantity: 1,
                                lineTotal: product.price,
                                imageUrl: product.imageUrl,
                              );
                              ref.read(cartProvider.notifier).addItem(cartItem);
                              context.showSnackBar('${product.name} added to cart');
                            }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    return CrossPlatformImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.fastfood_outlined,
        size: 40,
        color: AppColors.primaryOrange.withOpacity(0.4),
      ),
    );
  }

  Widget _buildPriceDisplay(Product product) {
    final priceAsync = ref.watch(catalogPriceProvider(
      (productId: product.id, price: product.price),
    ));
    return priceAsync.when(
      data: (result) {
        if (result != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.currency(product.price),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textHint,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 11,
                ),
              ),
              Text(
                Formatters.currency(result.tierPrice),
                style: AppTextStyles.priceMedium.copyWith(
                  color: AppColors.primaryOrange,
                  fontSize: 14,
                ),
              ),
            ],
          );
        }
        return Text(
          Formatters.currency(product.price),
          style: AppTextStyles.priceMedium.copyWith(
            color: AppColors.primaryOrange,
            fontSize: 14,
          ),
        );
      },
      loading: () => Text(
        Formatters.currency(product.price),
        style: AppTextStyles.priceMedium.copyWith(
          color: AppColors.primaryOrange,
          fontSize: 14,
        ),
      ),
      error: (_, __) => Text(
        Formatters.currency(product.price),
        style: AppTextStyles.priceMedium.copyWith(
          color: AppColors.primaryOrange,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCartBottomBar(cartState) {
    return GestureDetector(
      onTap: () => context.push('/pos/cart'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Cart icon with badge
              Stack(
                children: [
                  const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 28),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartState.itemCount}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              // Item count
              Expanded(
                child: Text(
                  '${cartState.itemCount} items in cart',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Total
              Text(
                Formatters.currency(cartState.total),
                style: AppTextStyles.priceMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, PosSession? session) async {
    final user = ref.read(currentUserProvider);
    if (user?.role == 'cashier' && session != null) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sesi Masih Aktif'),
          content: const Text(
            'Tutup sesi kasir terlebih dahulu sebelum logout.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await performLogout(ref);
    if (context.mounted) context.go('/auth');
  }

  Widget _buildDrawer(BuildContext context, PosSession? session) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Kompak POS',
                    style: AppTextStyles.heading2.copyWith(color: Colors.white),
                  ),
                  Text(
                    ref.watch(currentStoreProvider)?.name ?? 'Kompak Store',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Menu items
            _buildDrawerItem(
              icon: Icons.point_of_sale_rounded,
              label: 'POS',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // Laporan expandable
            _buildExpandableSection(
              context,
              icon: Icons.assessment_rounded,
              label: 'Laporan',
              children: [
                _buildSubMenuItem(
                  icon: Icons.access_time_rounded,
                  label: 'Laporan Sesi',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/reports/sessions');
                  },
                ),
                _buildSubMenuItem(
                  icon: Icons.list_alt_rounded,
                  label: 'List Order',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/orders');
                  },
                ),
                _buildSubMenuItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Laporan Penjualan',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/reports/sales');
                  },
                ),
              ],
            ),

            // Inventory expandable
            _buildExpandableSection(
              context,
              icon: Icons.inventory_2_rounded,
              label: 'Inventory',
              children: [
                _buildSubMenuItem(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'Restock Inventory',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/inventory/restock');
                  },
                ),
                _buildSubMenuItem(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Adjustment Inventory',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/inventory/adjustment');
                  },
                ),
                _buildSubMenuItem(
                  icon: Icons.analytics_rounded,
                  label: 'Laporan Inventory',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/inventory/report');
                  },
                ),
              ],
            ),

            _buildDrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                context.go('/dashboard');
              },
            ),

            const Divider(),

            if (session != null)
              _buildDrawerItem(
                icon: Icons.point_of_sale_outlined,
                label: 'Tutup Kasir',
                color: AppColors.warningAmber,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        CloseRegisterDialog(sessionId: session.id),
                  );
                },
              ),
            _buildDrawerItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            const Spacer(),
            // Logout
            _buildDrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: AppColors.errorRed,
              onTap: () async {
                Navigator.pop(context);
                await performLogout(ref);
                if (context.mounted) context.go('/auth');
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(
          color: color ?? AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildExpandableSection(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          label,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: AppSpacing.md),
        children: children,
      ),
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        label,
        style: AppTextStyles.bodyMedium,
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
