import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'manual_data.dart';

/// Wireframe-style illustrations for the manual book.
/// Each illustration is a simplified representation of a screen,
/// built using Containers, Icons, and Text — no image assets needed.
class ManualIllustration {
  ManualIllustration._();

  static Widget build(ManualIllustrationType type) {
    return switch (type) {
      ManualIllustrationType.loginPin => _loginPin(),
      ManualIllustrationType.loginRole => _loginRole(),
      ManualIllustrationType.loginSuccess => _loginSuccess(),
      ManualIllustrationType.dashboardOverview => _dashboardOverview(),
      ManualIllustrationType.dashboardQuickAction => _dashboardQuickAction(),
      ManualIllustrationType.dashboardFilter => _dashboardFilter(),
      ManualIllustrationType.dashboardDrawer => _dashboardDrawer(),
      ManualIllustrationType.posOpenRegister => _posOpenRegister(),
      ManualIllustrationType.posCatalog => _posCatalog(),
      ManualIllustrationType.posCart => _posCart(),
      ManualIllustrationType.posPayment => _posPayment(),
      ManualIllustrationType.posReceipt => _posReceipt(),
      ManualIllustrationType.posCloseRegister => _posCloseRegister(),
      ManualIllustrationType.orderList => _orderList(),
      ManualIllustrationType.orderDetail => _orderDetail(),
      ManualIllustrationType.orderFilter => _orderFilter(),
      ManualIllustrationType.inventoryList => _inventoryList(),
      ManualIllustrationType.inventoryRestock => _inventoryRestock(),
      ManualIllustrationType.inventoryAdjustment => _inventoryAdjustment(),
      ManualIllustrationType.inventoryReport => _inventoryReport(),
      ManualIllustrationType.inventoryDetail => _inventoryDetail(),
      ManualIllustrationType.attendancePin => _attendancePin(),
      ManualIllustrationType.attendanceSwipe => _attendanceSwipe(),
      ManualIllustrationType.attendanceCamera => _attendanceCamera(),
      ManualIllustrationType.attendanceConfirm => _attendanceConfirm(),
      ManualIllustrationType.attendanceHistory => _attendanceHistory(),
      ManualIllustrationType.kitchenDisplay => _kitchenDisplay(),
      ManualIllustrationType.kitchenStatus => _kitchenStatus(),
      ManualIllustrationType.kitchenRole => _kitchenRole(),
      ManualIllustrationType.reportSession => _reportSession(),
      ManualIllustrationType.reportSessionDetail => _reportSessionDetail(),
      ManualIllustrationType.reportSales => _reportSales(),
      ManualIllustrationType.reportFilter => _reportFilter(),
      ManualIllustrationType.masterProductList => _masterProductList(),
      ManualIllustrationType.masterProductForm => _masterProductForm(),
      ManualIllustrationType.masterCategory => _masterCategory(),
      ManualIllustrationType.masterUserList => _masterUserList(),
      ManualIllustrationType.masterUserForm => _masterUserForm(),
      ManualIllustrationType.masterCustomer => _masterCustomer(),
      ManualIllustrationType.masterPaymentMethod => _masterPaymentMethod(),
      ManualIllustrationType.masterPricelist => _masterPricelist(),
      ManualIllustrationType.masterCharge => _masterCharge(),
      ManualIllustrationType.masterPromotion => _masterPromotion(),
      ManualIllustrationType.settingsStore => _settingsStore(),
      ManualIllustrationType.settingsPrinter => _settingsPrinter(),
      ManualIllustrationType.settingsTelegram => _settingsTelegram(),
      ManualIllustrationType.settingsLanSync => _settingsLanSync(),
      ManualIllustrationType.settingsBranch => _settingsBranch(),
      ManualIllustrationType.settingsRole => _settingsRole(),
      ManualIllustrationType.settingsTerminal => _settingsTerminal(),
      ManualIllustrationType.demoDataLoad => _demoDataLoad(),
      ManualIllustrationType.demoDataPin => _demoDataPin(),
      ManualIllustrationType.demoDataTest => _demoDataTest(),
      ManualIllustrationType.generic => _generic('', Icons.help_outline),
    };
  }

  // ─── Shared Building Blocks ─────────────────────────────────

  static Widget _phoneFrame({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 380),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.scaffoldWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderGrey, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }

  static Widget _fakeAppBar(String title, {Color? color, List<Widget>? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: color ?? AppColors.primaryOrange,
      child: Row(
        children: [
          const Icon(Icons.arrow_back, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...trailing,
        ],
      ),
    );
  }

  static Widget _fakeBottomBar(String label, {Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: color ?? AppColors.primaryOrange,
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  static Widget _fakeCard({
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primaryOrange)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: iconColor ?? AppColors.primaryOrange),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 7, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 12, color: AppColors.textHint),
        ],
      ),
    );
  }

  static Widget _fakeButton(String label, {Color? color, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  static Widget _fakeTextField(String hint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Text(hint,
          style: TextStyle(fontSize: 8, color: AppColors.textHint)),
    );
  }

  static Widget _fakeGridItem(String label, IconData icon, {Color? color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.primaryOrange),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  static Widget _annotation(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warningAmber, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded,
              size: 10, color: AppColors.warningAmber),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 7,
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static Widget _kpiMini(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(height: 2),
          Text(value,
              style:
                  TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: TextStyle(fontSize: 6, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── Login ──────────────────────────────────────────────────

  static Widget _loginPin() {
    return _phoneFrame(
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.lock_rounded,
              size: 32, color: AppColors.primaryOrange),
          const SizedBox(height: 8),
          const Text('Masukkan PIN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                4,
                (i) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < 2
                            ? AppColors.primaryOrange
                            : AppColors.borderGrey,
                      ),
                    )),
          ),
          const SizedBox(height: 12),
          // Numpad grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                  9,
                  (i) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      )),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _loginRole() {
    return _phoneFrame(
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.badge_rounded, size: 28, color: AppColors.primaryOrange),
          const SizedBox(height: 8),
          const Text('Akses Berdasarkan Role',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _fakeCard(
              title: 'Owner / Admin',
              subtitle: 'Dashboard lengkap',
              icon: Icons.admin_panel_settings,
              iconColor: AppColors.successGreen),
          _fakeCard(
              title: 'Kasir',
              subtitle: 'Halaman POS',
              icon: Icons.point_of_sale,
              iconColor: AppColors.primaryOrange),
          _fakeCard(
              title: 'Kitchen',
              subtitle: 'Kitchen Display',
              icon: Icons.restaurant,
              iconColor: AppColors.discountRed),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _loginSuccess() {
    return _phoneFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                size: 28, color: AppColors.successGreen),
          ),
          const SizedBox(height: 12),
          const Text('Login Berhasil!',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Sesi akan disimpan otomatis',
              style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── Dashboard ──────────────────────────────────────────────

  static Widget _dashboardOverview() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Dashboard'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _kpiMini('Penjualan', 'Rp 2.5jt', Icons.trending_up,
                    AppColors.successGreen),
                _kpiMini('Transaksi', '45', Icons.receipt_long,
                    AppColors.primaryOrange),
                _kpiMini('Rata-rata', 'Rp 55rb', Icons.analytics,
                    AppColors.infoBlue),
                _kpiMini('Sesi Aktif', '1', Icons.store,
                    AppColors.warningAmber),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Chart placeholder
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGrey, width: 0.5),
            ),
            child: Center(
              child: Icon(Icons.show_chart_rounded,
                  size: 28, color: AppColors.primaryOrange.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _dashboardQuickAction() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Dashboard'),
          // Quick action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            color: AppColors.primaryOrange.withValues(alpha: 0.85),
            child: Row(
              children: [
                _quickActionBtn(Icons.point_of_sale_rounded, 'POS'),
                const SizedBox(width: 4),
                _quickActionBtn(Icons.list_alt_rounded, 'Order'),
                const SizedBox(width: 4),
                _quickActionBtn(Icons.assessment_rounded, 'Laporan'),
                const SizedBox(width: 4),
                _quickActionBtn(Icons.fingerprint_rounded, 'Absensi'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _annotation('Tap untuk navigasi cepat'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _quickActionBtn(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 6)),
          ],
        ),
      ),
    );
  }

  static Widget _dashboardFilter() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Dashboard'),
          const SizedBox(height: 8),
          // Filter dropdowns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderGrey),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store, size: 10, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        const Text('Semua Cabang',
                            style: TextStyle(fontSize: 7)),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            size: 12, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderGrey),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.point_of_sale, size: 10, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        const Text('Terminal',
                            style: TextStyle(fontSize: 7)),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            size: 12, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _annotation('Filter data per cabang/terminal'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _dashboardDrawer() {
    return _phoneFrame(
      child: Row(
        children: [
          // Drawer
          Container(
            width: 130,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  color: AppColors.primaryOrange,
                  child: Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text('Kompak POS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _drawerItem(Icons.point_of_sale, 'POS'),
                _drawerItem(Icons.assessment, 'Laporan'),
                _drawerItem(Icons.inventory_2, 'Inventori'),
                _drawerItem(Icons.restaurant, 'Kitchen'),
                _drawerItem(Icons.dashboard, 'Dashboard'),
                _drawerItem(Icons.settings, 'Settings'),
                const Spacer(),
                _drawerItem(Icons.logout, 'Logout'),
                const SizedBox(height: 6),
              ],
            ),
          ),
          // Dimmed content
          Expanded(
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  static Widget _drawerItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  // ─── POS ────────────────────────────────────────────────────

  static Widget _posOpenRegister() {
    return _phoneFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.point_of_sale_rounded,
              size: 36, color: AppColors.primaryOrange),
          const SizedBox(height: 8),
          const Text('Buka Register',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _fakeTextField('Saldo awal kas (Rp)'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _fakeButton('Buka Register',
                width: double.infinity, color: AppColors.successGreen),
          ),
          const SizedBox(height: 6),
          _annotation('Masukkan saldo awal kas'),
        ],
      ),
    );
  }

  static Widget _posCatalog() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('POS Kasir', trailing: [
            Icon(Icons.qr_code_scanner, size: 12, color: Colors.white),
          ]),
          // Search bar
          _fakeTextField('Cari produk...'),
          // Category chips
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('Semua', true),
                _chip('Makanan', false),
                _chip('Minuman', false),
                _chip('Snack', false),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Product grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.85,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _fakeGridItem('Nasi Goreng', Icons.lunch_dining),
                  _fakeGridItem('Es Teh', Icons.local_cafe),
                  _fakeGridItem('Mie Ayam', Icons.ramen_dining),
                  _fakeGridItem('Kopi Susu', Icons.coffee),
                ],
              ),
            ),
          ),
          _fakeBottomBar('Keranjang (3 item) — Rp 85.000'),
        ],
      ),
    );
  }

  static Widget _chip(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryOrange : AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 7,
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
    );
  }

  static Widget _posCart() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Keranjang'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(6),
              children: [
                _cartItem('Nasi Goreng', 'Rp 25.000', '2'),
                _cartItem('Es Teh Manis', 'Rp 8.000', '1'),
                _cartItem('Mie Ayam Bakso', 'Rp 27.000', '1'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                    Text('Rp 85.000',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryOrange)),
                  ],
                ),
                const SizedBox(height: 4),
                _fakeButton('Bayar', width: double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _cartItem(String name, String price, String qty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w600)),
                Text(price,
                    style: TextStyle(
                        fontSize: 7, color: AppColors.primaryOrange)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('x$qty', style: const TextStyle(fontSize: 7)),
          ),
        ],
      ),
    );
  }

  static Widget _posPayment() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Pembayaran'),
          const SizedBox(height: 12),
          Text('Total Pembayaran',
              style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
          const Text('Rp 85.000',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _fakeCard(
              title: 'Cash', subtitle: 'Tunai', icon: Icons.money, iconColor: AppColors.successGreen),
          _fakeCard(
              title: 'QRIS', subtitle: 'Scan QR', icon: Icons.qr_code, iconColor: AppColors.infoBlue),
          _fakeCard(
              title: 'Transfer', subtitle: 'Bank', icon: Icons.account_balance, iconColor: AppColors.warningAmber),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child:
                _fakeButton('Proses Pembayaran', width: double.infinity),
          ),
        ],
      ),
    );
  }

  static Widget _posReceipt() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Struk', color: Colors.white),
          const Spacer(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('KOMPAK POS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                Divider(height: 8, color: AppColors.borderGrey),
                _receiptLine('Nasi Goreng x2', 'Rp 50.000'),
                _receiptLine('Es Teh x1', 'Rp 8.000'),
                _receiptLine('Mie Ayam x1', 'Rp 27.000'),
                Divider(height: 8, color: AppColors.borderGrey),
                _receiptLine('Total', 'Rp 85.000', bold: true),
                _receiptLine('Cash', 'Rp 100.000'),
                _receiptLine('Kembalian', 'Rp 15.000'),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    child: _fakeButton('Cetak',
                        color: AppColors.primaryOrange)),
                const SizedBox(width: 6),
                Expanded(
                    child: _fakeButton('Transaksi Baru',
                        color: AppColors.successGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _receiptLine(String left, String right, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left,
              style: TextStyle(
                  fontSize: 7,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(right,
              style: TextStyle(
                  fontSize: 7,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }

  static Widget _posCloseRegister() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Tutup Register'),
          const SizedBox(height: 10),
          _fakeCard(
              title: 'Saldo Awal', subtitle: 'Rp 500.000', icon: Icons.account_balance_wallet, iconColor: AppColors.infoBlue),
          _fakeCard(
              title: 'Total Penjualan', subtitle: 'Rp 850.000', icon: Icons.trending_up, iconColor: AppColors.successGreen),
          _fakeCard(
              title: 'Kas Akhir (Hitung Manual)', subtitle: 'Rp 1.350.000', icon: Icons.calculate, iconColor: AppColors.warningAmber),
          const SizedBox(height: 8),
          _fakeTextField('Masukkan kas akhir'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _fakeButton('Tutup & Kirim Laporan',
                width: double.infinity, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }

  // ─── Orders ─────────────────────────────────────────────────

  static Widget _orderList() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Pesanan'),
          _fakeTextField('Cari order...'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                _orderItem('ORD-001', 'Rp 85.000', 'Completed'),
                _orderItem('ORD-002', 'Rp 42.000', 'Completed'),
                _orderItem('ORD-003', 'Rp 120.000', 'Returned'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _orderItem(String id, String total, String status) {
    final color = status == 'Completed' ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id,
                    style: const TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w600)),
                Text(total,
                    style: TextStyle(
                        fontSize: 7, color: AppColors.primaryOrange)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 6, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static Widget _orderDetail() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Detail Order'),
          _fakeCard(title: 'ORD-001', subtitle: '07 Apr 2026, 10:30', icon: Icons.receipt, iconColor: Colors.teal),
          Divider(height: 1, indent: 10, endIndent: 10, color: AppColors.borderGrey),
          _cartItem('Nasi Goreng', 'Rp 25.000', '2'),
          _cartItem('Es Teh', 'Rp 8.000', '1'),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                Text('Rp 58.000',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _orderFilter() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Pesanan'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(child: _fakeButton('Cabang', color: AppColors.surfaceGrey)),
                const SizedBox(width: 4),
                Expanded(child: _fakeButton('Terminal', color: AppColors.surfaceGrey)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _annotation('Filter untuk mencari order'),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── Inventory ──────────────────────────────────────────────

  static Widget _inventoryList() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Inventori', color: AppColors.warningAmber),
          _fakeTextField('Cari produk...'),
          _inventoryItem('Nasi Goreng', '25 pcs', AppColors.successGreen),
          _inventoryItem('Kopi Susu', '3 pcs', AppColors.warningAmber),
          _inventoryItem('Mie Ayam', '0 pcs', AppColors.errorRed),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _inventoryItem(String name, String stock, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w600)),
          ),
          Text(stock,
              style: TextStyle(
                  fontSize: 8, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _inventoryRestock() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Restock', color: AppColors.warningAmber),
          const SizedBox(height: 8),
          _fakeTextField('Pilih produk'),
          _fakeTextField('Jumlah masuk'),
          _fakeTextField('Catatan (opsional)'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _fakeButton('Simpan Restock',
                width: double.infinity, color: AppColors.successGreen),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _inventoryAdjustment() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Adjustment', color: AppColors.warningAmber),
          const SizedBox(height: 8),
          _fakeTextField('Pilih produk'),
          _fakeTextField('Stok di sistem: 25'),
          _fakeTextField('Stok aktual (fisik)'),
          _fakeTextField('Alasan koreksi'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _fakeButton('Simpan Adjustment',
                width: double.infinity, color: AppColors.warningAmber),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _inventoryReport() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Laporan Inventori', color: AppColors.warningAmber),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                    child: _kpiMini(
                        'Total SKU', '48', Icons.category, AppColors.primaryOrange)),
                const SizedBox(width: 4),
                Expanded(
                    child: _kpiMini('Low Stock', '5', Icons.warning_rounded,
                        AppColors.warningAmber)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _inventoryItem('Kopi Susu', '3 pcs', AppColors.warningAmber),
          _inventoryItem('Mie Ayam', '0 pcs', AppColors.errorRed),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _inventoryDetail() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Detail Stok', color: AppColors.warningAmber),
          _fakeCard(
              title: 'Nasi Goreng',
              subtitle: 'Stok: 25 pcs',
              icon: Icons.lunch_dining,
              iconColor: AppColors.warningAmber),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Riwayat Pergerakan',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
            ),
          ),
          _fakeCard(title: 'Restock +10', subtitle: '05 Apr', icon: Icons.add_circle, iconColor: AppColors.successGreen),
          _fakeCard(title: 'Terjual -2', subtitle: '06 Apr', icon: Icons.remove_circle, iconColor: AppColors.errorRed),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── Attendance ─────────────────────────────────────────────

  static Widget _attendancePin() {
    return _phoneFrame(
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fingerprint_rounded,
                size: 22, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          const Text('Absensi Karyawan',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const Text('Masukkan PIN untuk memulai',
              style: TextStyle(fontSize: 7, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                6,
                (i) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < 3
                            ? Colors.deepPurple
                            : AppColors.borderGrey,
                      ),
                    )),
          ),
          const Spacer(),
          _annotation('Ketik PIN → verifikasi otomatis'),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static Widget _attendanceSwipe() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Absensi', color: Colors.white),
          const Spacer(),
          Icon(Icons.person_rounded, size: 32, color: Colors.deepPurple),
          const SizedBox(height: 4),
          const Text('Budi Santoso',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // Swipe button wireframe
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text('Geser untuk Absen Masuk',
                      style: TextStyle(
                          fontSize: 8,
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w600)),
                ),
                Positioned(
                  left: 3,
                  top: 3,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.successGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.login_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _annotation('Geser ke kanan →'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _attendanceCamera() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Absensi', color: Colors.white),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_rounded,
                        size: 36, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Posisikan wajah di tengah',
                          style: TextStyle(color: Colors.white70, fontSize: 7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                    child: _fakeButton('Batal', color: Colors.grey)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: _fakeButton('Ambil Foto',
                        color: AppColors.primaryOrange)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _attendanceConfirm() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Absensi', color: Colors.white),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.image_rounded,
                        size: 40, color: Colors.grey),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 8, color: Colors.white),
                              const SizedBox(width: 2),
                              Text('Jl. Contoh No. 123',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 7)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.explore, size: 7, color: Colors.white70),
                              const SizedBox(width: 2),
                              Text('-6.2088, 106.8456',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 6)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(child: _fakeButton('Ulangi', color: Colors.grey)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: _fakeButton('Konfirmasi',
                        color: AppColors.primaryOrange)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _attendanceHistory() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Riwayat Absensi', color: Colors.white),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('07 April 2026',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _attendanceItem('Masuk', '08:02', AppColors.successGreen),
          _attendanceItem('Pulang', '17:15', AppColors.errorRed),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('06 April 2026',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _attendanceItem('Masuk', '07:55', AppColors.successGreen),
          _attendanceItem('Pulang', '16:30', AppColors.errorRed),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _attendanceItem(String type, String time, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderGrey, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.photo, size: 12, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(type,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(time,
                style: TextStyle(
                    fontSize: 7, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Kitchen ────────────────────────────────────────────────

  static Widget _kitchenDisplay() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Kitchen Display', color: AppColors.discountRed),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  _kitchenCard('ORD-005', ['Nasi Goreng x2', 'Es Teh x1']),
                  const SizedBox(height: 4),
                  _kitchenCard('ORD-006', ['Mie Ayam x1', 'Kopi Susu x2']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _kitchenCard(String order, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warningAmber, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order,
              style:
                  const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item,
                    style: const TextStyle(fontSize: 7)),
              )),
        ],
      ),
    );
  }

  static Widget _kitchenStatus() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Kitchen Display', color: AppColors.discountRed),
          const SizedBox(height: 8),
          _fakeCard(
              title: 'ORD-005',
              subtitle: 'Tandai selesai',
              icon: Icons.check_circle,
              iconColor: AppColors.successGreen),
          _annotation('Tap untuk update status'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _kitchenRole() {
    return _phoneFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_rounded,
              size: 36, color: AppColors.discountRed),
          const SizedBox(height: 8),
          const Text('Kitchen Display',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Khusus role "Kitchen"',
              style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _annotation('Login dengan PIN role Kitchen'),
        ],
      ),
    );
  }

  // ─── Reports ────────────────────────────────────────────────

  static Widget _reportSession() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Laporan Sesi', color: AppColors.infoBlue),
          _fakeCard(title: 'Sesi #1 — 07 Apr', subtitle: 'Rp 850.000 | Kasir: Budi', icon: Icons.timer, iconColor: AppColors.infoBlue),
          _fakeCard(title: 'Sesi #2 — 06 Apr', subtitle: 'Rp 620.000 | Kasir: Sari', icon: Icons.timer_off, iconColor: AppColors.textSecondary),
          _fakeCard(title: 'Sesi #3 — 05 Apr', subtitle: 'Rp 1.250.000 | Kasir: Budi', icon: Icons.timer_off, iconColor: AppColors.textSecondary),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _reportSessionDetail() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Detail Sesi', color: AppColors.infoBlue),
          _fakeCard(title: 'Saldo Awal', subtitle: 'Rp 500.000', icon: Icons.account_balance_wallet, iconColor: AppColors.infoBlue),
          _fakeCard(title: 'Penjualan', subtitle: 'Rp 850.000', icon: Icons.trending_up, iconColor: AppColors.successGreen),
          _fakeCard(title: 'Kas Akhir', subtitle: 'Rp 1.350.000', icon: Icons.calculate, iconColor: AppColors.warningAmber),
          _fakeCard(title: 'Selisih', subtitle: 'Rp 0 (Pas)', icon: Icons.check_circle, iconColor: AppColors.successGreen),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _reportSales() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Laporan Penjualan', color: AppColors.infoBlue),
          const SizedBox(height: 6),
          // Chart placeholder
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGrey, width: 0.5),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _MiniChartPainter(),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                    child: _kpiMini('Revenue', 'Rp 2.5jt',
                        Icons.trending_up, AppColors.successGreen)),
                const SizedBox(width: 4),
                Expanded(
                    child: _kpiMini('Transaksi', '45', Icons.receipt,
                        AppColors.primaryOrange)),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _reportFilter() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Laporan', color: AppColors.infoBlue),
          const SizedBox(height: 8),
          _fakeTextField('Pilih cabang'),
          _fakeTextField('Pilih terminal'),
          _fakeTextField('Rentang tanggal'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _fakeButton('Terapkan Filter',
                width: double.infinity, color: AppColors.infoBlue),
          ),
          const SizedBox(height: 4),
          _annotation('Filter berlaku untuk semua laporan'),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── Master Data ────────────────────────────────────────────

  static Widget _masterProductList() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Produk'),
          _fakeTextField('Cari produk...'),
          _fakeCard(title: 'Nasi Goreng', subtitle: 'Rp 25.000', icon: Icons.lunch_dining, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Es Teh Manis', subtitle: 'Rp 8.000', icon: Icons.local_cafe, iconColor: AppColors.infoBlue),
          _fakeCard(title: 'Mie Ayam', subtitle: 'Rp 27.000', icon: Icons.ramen_dining, iconColor: AppColors.warningAmber),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _fakeButton('+ Tambah Produk',
                width: double.infinity, color: AppColors.primaryOrange),
          ),
        ],
      ),
    );
  }

  static Widget _masterProductForm() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Tambah Produk'),
          const SizedBox(height: 6),
          _fakeTextField('Nama produk'),
          _fakeTextField('Harga jual (Rp)'),
          _fakeTextField('Kategori'),
          _fakeTextField('Barcode (opsional)'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _fakeButton('Simpan',
                width: double.infinity, color: AppColors.primaryOrange),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _masterCategory() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Kategori'),
          _fakeCard(title: 'Makanan', subtitle: '12 produk', icon: Icons.lunch_dining, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Minuman', subtitle: '8 produk', icon: Icons.local_cafe, iconColor: AppColors.infoBlue),
          _fakeCard(title: 'Snack', subtitle: '5 produk', icon: Icons.cookie, iconColor: AppColors.warningAmber),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _fakeButton('+ Tambah Kategori', width: double.infinity),
          ),
        ],
      ),
    );
  }

  static Widget _masterUserList() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Users'),
          _fakeCard(title: 'Owner Kompak', subtitle: 'Role: Owner', icon: Icons.admin_panel_settings, iconColor: AppColors.successGreen),
          _fakeCard(title: 'Budi', subtitle: 'Role: Kasir', icon: Icons.person, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Sari', subtitle: 'Role: Kasir', icon: Icons.person, iconColor: AppColors.primaryOrange),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _masterUserForm() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Tambah User'),
          const SizedBox(height: 6),
          _fakeTextField('Nama'),
          _fakeTextField('PIN (4-6 digit)'),
          _fakeTextField('Role'),
          _fakeTextField('Terminal (opsional)'),
          const SizedBox(height: 4),
          // Attendance toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.borderGrey, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.fingerprint, size: 12, color: AppColors.successGreen),
                const SizedBox(width: 4),
                Expanded(
                    child: Text('Akses Absensi',
                        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600))),
                Container(
                  width: 24,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _fakeButton('Simpan', width: double.infinity),
          ),
        ],
      ),
    );
  }

  static Widget _masterCustomer() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Pelanggan'),
          _fakeCard(title: 'Ahmad', subtitle: '0812-xxxx-xxxx', icon: Icons.person, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Rina', subtitle: '0856-xxxx-xxxx', icon: Icons.person, iconColor: AppColors.primaryOrange),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _fakeButton('+ Tambah Pelanggan', width: double.infinity),
          ),
        ],
      ),
    );
  }

  static Widget _masterPaymentMethod() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Metode Pembayaran'),
          _fakeCard(title: 'Cash', subtitle: 'Aktif', icon: Icons.money, iconColor: AppColors.successGreen),
          _fakeCard(title: 'QRIS', subtitle: 'Aktif', icon: Icons.qr_code, iconColor: AppColors.infoBlue),
          _fakeCard(title: 'Transfer Bank', subtitle: 'Aktif', icon: Icons.account_balance, iconColor: AppColors.warningAmber),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _masterPricelist() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Pricelist & Promosi'),
          _fakeCard(title: 'Harga Cabang Selatan', subtitle: '15 produk', icon: Icons.price_check, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Promo Weekday', subtitle: 'Diskon 10%', icon: Icons.local_offer, iconColor: AppColors.discountRed),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _masterCharge() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Master Biaya'),
          _fakeCard(title: 'PPN', subtitle: '11%', icon: Icons.receipt, iconColor: AppColors.warningAmber),
          _fakeCard(title: 'Service Charge', subtitle: '5%', icon: Icons.room_service, iconColor: AppColors.primaryOrange),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _masterPromotion() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Promosi'),
          _fakeCard(title: 'Happy Hour', subtitle: 'Diskon 20% minuman', icon: Icons.local_offer, iconColor: AppColors.discountRed),
          _fakeCard(title: 'Bundel Hemat', subtitle: 'Beli 2 gratis 1', icon: Icons.card_giftcard, iconColor: AppColors.successGreen),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── Settings ───────────────────────────────────────────────

  static Widget _settingsStore() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Pengaturan Toko'),
          const SizedBox(height: 6),
          _fakeTextField('Nama toko'),
          _fakeTextField('Alamat'),
          _fakeTextField('No. Telepon'),
          _fakeTextField('Header struk'),
          _fakeTextField('Footer struk'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _fakeButton('Simpan', width: double.infinity),
          ),
        ],
      ),
    );
  }

  static Widget _settingsPrinter() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Printer'),
          const SizedBox(height: 6),
          _fakeCard(title: 'Bluetooth Printer', subtitle: 'Tidak terhubung', icon: Icons.print, iconColor: AppColors.textSecondary),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _fakeButton('Scan Perangkat',
                width: double.infinity, color: AppColors.infoBlue),
          ),
          const SizedBox(height: 6),
          _annotation('Nyalakan Bluetooth terlebih dahulu'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _settingsTelegram() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Telegram'),
          const SizedBox(height: 6),
          _fakeTextField('Bot Token'),
          _fakeTextField('Chat ID'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                    child: _fakeButton('Test', color: AppColors.infoBlue)),
                const SizedBox(width: 6),
                Expanded(child: _fakeButton('Simpan')),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _annotation('Buat bot via @BotFather'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _settingsLanSync() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('LAN Sync'),
          const SizedBox(height: 8),
          _fakeCard(title: 'Mode Server', subtitle: 'Perangkat utama', icon: Icons.dns, iconColor: AppColors.successGreen),
          _fakeCard(title: 'Mode Client', subtitle: 'Perangkat kedua', icon: Icons.devices, iconColor: AppColors.infoBlue),
          const SizedBox(height: 6),
          _annotation('Kedua device harus 1 WiFi'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _settingsBranch() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Kelola Cabang'),
          _fakeCard(title: 'HQ — Kompak Pusat', subtitle: '2 terminal', icon: Icons.store_mall_directory, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Cabang Selatan', subtitle: '2 terminal', icon: Icons.store, iconColor: Colors.teal),
          _fakeCard(title: 'Cabang Timur', subtitle: '1 terminal', icon: Icons.store, iconColor: Colors.teal),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _settingsRole() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Kelola Role'),
          _fakeCard(title: 'Owner', subtitle: 'Full access', icon: Icons.shield, iconColor: AppColors.successGreen),
          _fakeCard(title: 'Admin', subtitle: '17 permissions', icon: Icons.admin_panel_settings, iconColor: AppColors.primaryOrange),
          _fakeCard(title: 'Kasir', subtitle: '3 permissions', icon: Icons.person, iconColor: AppColors.infoBlue),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _settingsTerminal() {
    return _phoneFrame(
      child: Column(
        children: [
          _fakeAppBar('Kelola Terminal'),
          _fakeCard(title: 'Kasir 1', subtitle: 'Aktif', icon: Icons.point_of_sale, iconColor: AppColors.successGreen),
          _fakeCard(title: 'Kasir 2', subtitle: 'Aktif', icon: Icons.point_of_sale, iconColor: AppColors.successGreen),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── Demo Data ──────────────────────────────────────────────

  static Widget _demoDataLoad() {
    return _phoneFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_rounded, size: 36, color: Colors.deepPurple),
          const SizedBox(height: 8),
          const Text('Muat Data Demo',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '3 toko + 5 terminal\nKatalog + transaksi demo',
              style: TextStyle(fontSize: 7, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          _fakeButton('Muat Data Demo', color: Colors.deepPurple),
        ],
      ),
    );
  }

  static Widget _demoDataPin() {
    return _phoneFrame(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.vpn_key_rounded, size: 28, color: Colors.deepPurple),
          const SizedBox(height: 6),
          const Text('PIN Demo',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _pinRow('9999', 'Owner'),
          _pinRow('1111', 'Admin'),
          _pinRow('2222', 'Kasir 1'),
          _pinRow('3333', 'Kasir 2'),
          _pinRow('4444', 'Kasir 3'),
          _pinRow('5555', 'Kasir 4'),
          const Spacer(),
        ],
      ),
    );
  }

  static Widget _pinRow(String pin, String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(pin,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Text(role, style: const TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static Widget _demoDataTest() {
    return _phoneFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_rounded,
              size: 32, color: Colors.deepPurple.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          const Text('Uji Coba Fitur',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _testItem(Icons.point_of_sale, 'Buat transaksi POS'),
          _testItem(Icons.dashboard, 'Lihat dashboard'),
          _testItem(Icons.inventory_2, 'Kelola inventori'),
          _testItem(Icons.fingerprint, 'Absensi karyawan'),
          _testItem(Icons.compare, 'Bandingkan role'),
        ],
      ),
    );
  }

  static Widget _testItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  // ─── Generic fallback ─────────────────────────────────────

  static Widget _generic(String title, IconData icon) {
    return _phoneFrame(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.textHint),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Mini Chart Painter ──────────────────────────────────────

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryOrange.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.15, size.height * 0.5),
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.45, size.height * 0.35),
      Offset(size.width * 0.6, size.height * 0.4),
      Offset(size.width * 0.75, size.height * 0.2),
      Offset(size.width, size.height * 0.15),
    ];

    // Fill area
    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, paint);

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
