import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// ─── Data Models ────────────────────────────────────────────────

class ManualSection {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<ManualStep> steps;

  const ManualSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.steps,
  });
}

class ManualStep {
  final String title;
  final String description;
  final ManualIllustrationType illustration;

  const ManualStep({
    required this.title,
    required this.description,
    required this.illustration,
  });
}

enum ManualIllustrationType {
  loginPin,
  loginRole,
  loginSuccess,
  dashboardOverview,
  dashboardQuickAction,
  dashboardFilter,
  dashboardDrawer,
  posOpenRegister,
  posCatalog,
  posCart,
  posPayment,
  posReceipt,
  posCloseRegister,
  orderList,
  orderDetail,
  orderFilter,
  inventoryList,
  inventoryRestock,
  inventoryAdjustment,
  inventoryReport,
  inventoryDetail,
  attendancePin,
  attendanceSwipe,
  attendanceCamera,
  attendanceConfirm,
  attendanceHistory,
  kitchenDisplay,
  kitchenStatus,
  kitchenRole,
  reportSession,
  reportSessionDetail,
  reportSales,
  reportFilter,
  masterProductList,
  masterProductForm,
  masterCategory,
  masterUserList,
  masterUserForm,
  masterCustomer,
  masterPaymentMethod,
  masterPricelist,
  masterCharge,
  masterPromotion,
  settingsStore,
  settingsPrinter,
  settingsTelegram,
  settingsLanSync,
  settingsBranch,
  settingsRole,
  settingsTerminal,
  demoDataLoad,
  demoDataPin,
  demoDataTest,
  generic,
}

// ─── Content ────────────────────────────────────────────────────

const manualSections = <ManualSection>[
  // ── 1. Login ──
  ManualSection(
    id: 'login',
    title: 'Login & Autentikasi',
    subtitle: 'Masuk ke aplikasi dengan PIN',
    icon: Icons.lock_rounded,
    color: AppColors.primaryOrange,
    steps: [
      ManualStep(
        title: 'Masukkan PIN',
        description:
            'Buka aplikasi Kompak POS. Pada halaman login, masukkan PIN '
            '4-6 digit Anda menggunakan numpad yang tersedia.\n\n'
            'PIN bersifat unik untuk setiap pengguna. Hubungi admin/owner '
            'jika Anda belum memiliki PIN.',
        illustration: ManualIllustrationType.loginPin,
      ),
      ManualStep(
        title: 'Akses Berdasarkan Role',
        description:
            'Setelah login berhasil, Anda akan diarahkan ke halaman sesuai '
            'role:\n\n'
            '- Owner / Admin: Dashboard lengkap\n'
            '- Branch Manager: Dashboard cabang\n'
            '- Kasir: Langsung ke halaman POS\n'
            '- Kitchen: Langsung ke Kitchen Display\n\n'
            'Setiap role memiliki hak akses yang berbeda ke fitur aplikasi.',
        illustration: ManualIllustrationType.loginRole,
      ),
      ManualStep(
        title: 'Restore Sesi Otomatis',
        description:
            'Jika sebelumnya Anda sudah login dan belum logout, aplikasi '
            'akan otomatis mengembalikan sesi Anda saat dibuka kembali.\n\n'
            'Untuk mengganti akun, logout terlebih dahulu melalui menu '
            'di dashboard.',
        illustration: ManualIllustrationType.loginSuccess,
      ),
    ],
  ),

  // ── 2. Dashboard ──
  ManualSection(
    id: 'dashboard',
    title: 'Dashboard',
    subtitle: 'Ringkasan performa bisnis',
    icon: Icons.dashboard_rounded,
    color: AppColors.infoBlue,
    steps: [
      ManualStep(
        title: 'Lihat Ringkasan Bisnis',
        description:
            'Dashboard menampilkan KPI penting bisnis Anda:\n\n'
            '- Total penjualan bulan ini vs bulan lalu\n'
            '- Jumlah transaksi dan rata-rata order\n'
            '- Tren 7 hari dan 30 hari terakhir\n'
            '- Status sesi kasir (aktif/tutup)\n\n'
            'Data diperbarui otomatis setiap kali halaman dibuka.',
        illustration: ManualIllustrationType.dashboardOverview,
      ),
      ManualStep(
        title: 'Aksi Cepat di Header',
        description:
            'Di bagian atas layar terdapat 4 tombol aksi cepat:\n\n'
            '- POS: Langsung ke halaman kasir\n'
            '- Order: Lihat daftar pesanan\n'
            '- Laporan: Buka laporan sesi\n'
            '- Absensi: Absen karyawan via PIN\n\n'
            'Gunakan tombol ini untuk navigasi cepat tanpa perlu membuka menu.',
        illustration: ManualIllustrationType.dashboardQuickAction,
      ),
      ManualStep(
        title: 'Filter Cabang & Terminal',
        description:
            'Jika Anda adalah owner/admin dengan banyak cabang, gunakan '
            'dropdown filter di bawah header untuk melihat data per cabang '
            'atau per terminal.\n\n'
            'Pilih "Semua Cabang" untuk melihat data gabungan.',
        illustration: ManualIllustrationType.dashboardFilter,
      ),
      ManualStep(
        title: 'Menu Navigasi (Drawer)',
        description:
            'Tap ikon menu (hamburger) di kiri atas untuk membuka menu '
            'navigasi samping. Menu ini berisi:\n\n'
            '- POS, Laporan, Inventory, Kitchen Display\n'
            '- Dashboard, Settings, Logout\n'
            '- Tutup Kasir (jika sesi aktif)\n\n'
            'Menu yang tampil disesuaikan dengan role Anda.',
        illustration: ManualIllustrationType.dashboardDrawer,
      ),
    ],
  ),

  // ── 3. POS / Kasir ──
  ManualSection(
    id: 'pos',
    title: 'POS / Kasir',
    subtitle: 'Proses transaksi penjualan',
    icon: Icons.point_of_sale_rounded,
    color: AppColors.successGreen,
    steps: [
      ManualStep(
        title: 'Buka Register',
        description:
            'Sebelum mulai transaksi, Anda perlu membuka register:\n\n'
            '1. Masuk ke halaman POS\n'
            '2. Masukkan saldo awal kas di mesin kasir\n'
            '3. Tap "Buka Register"\n\n'
            'Saldo awal ini akan digunakan untuk pencocokan saat tutup kasir.',
        illustration: ManualIllustrationType.posOpenRegister,
      ),
      ManualStep(
        title: 'Pilih Produk',
        description:
            'Katalog produk ditampilkan dalam bentuk grid.\n\n'
            '- Scroll untuk melihat semua produk\n'
            '- Gunakan pencarian di atas untuk mencari produk\n'
            '- Filter berdasarkan kategori dengan tab horizontal\n'
            '- Scan barcode dengan tap ikon barcode\n\n'
            'Tap produk untuk menambahkannya ke keranjang.',
        illustration: ManualIllustrationType.posCatalog,
      ),
      ManualStep(
        title: 'Atur Keranjang',
        description:
            'Keranjang menampilkan daftar produk yang dipilih:\n\n'
            '- Gunakan tombol +/- untuk mengubah jumlah\n'
            '- Geser item ke kiri untuk menghapus\n'
            '- Lihat subtotal di bagian bawah\n'
            '- Biaya tambahan (pajak, service) otomatis dihitung\n\n'
            'Tap "Bayar" untuk melanjutkan ke pembayaran.',
        illustration: ManualIllustrationType.posCart,
      ),
      ManualStep(
        title: 'Proses Pembayaran',
        description:
            'Halaman pembayaran menampilkan total yang harus dibayar:\n\n'
            '- Pilih metode pembayaran (Cash, QRIS, Transfer, dll)\n'
            '- Untuk Cash: masukkan nominal yang diterima\n'
            '- Kembalian dihitung otomatis\n'
            '- Tap "Proses Pembayaran" untuk menyelesaikan\n\n'
            'Transaksi akan tersimpan dan mengurangi stok otomatis.',
        illustration: ManualIllustrationType.posPayment,
      ),
      ManualStep(
        title: 'Cetak Struk',
        description:
            'Setelah pembayaran berhasil, struk transaksi ditampilkan:\n\n'
            '- Tap "Cetak" untuk mencetak via printer Bluetooth\n'
            '- Tap "Bagikan" untuk share struk sebagai gambar\n'
            '- Tap "Transaksi Baru" untuk kembali ke katalog\n\n'
            'Pastikan printer Bluetooth sudah terhubung di menu Settings > Printer.',
        illustration: ManualIllustrationType.posReceipt,
      ),
      ManualStep(
        title: 'Tutup Register',
        description:
            'Di akhir shift, tutup register melalui menu drawer:\n\n'
            '1. Tap ikon menu > Tutup Kasir\n'
            '2. Masukkan jumlah kas akhir yang dihitung manual\n'
            '3. Sistem menampilkan ringkasan penjualan sesi\n'
            '4. Selisih kas (jika ada) akan dicatat\n'
            '5. Laporan otomatis terkirim ke Telegram (jika dikonfigurasi)\n\n'
            'Absensi pending juga akan dikirim saat tutup register.',
        illustration: ManualIllustrationType.posCloseRegister,
      ),
    ],
  ),

  // ── 4. Pesanan ──
  ManualSection(
    id: 'orders',
    title: 'Pesanan',
    subtitle: 'Lihat dan kelola daftar order',
    icon: Icons.receipt_long_rounded,
    color: Colors.teal,
    steps: [
      ManualStep(
        title: 'Daftar Pesanan',
        description:
            'Halaman Pesanan menampilkan semua transaksi:\n\n'
            '- Urutkan berdasarkan tanggal (terbaru di atas)\n'
            '- Setiap order menampilkan nomor, total, status, dan waktu\n'
            '- Status: Completed (selesai), Returned (retur)\n'
            '- Nama kasir yang memproses juga terlihat\n\n'
            'Tap order untuk melihat detail.',
        illustration: ManualIllustrationType.orderList,
      ),
      ManualStep(
        title: 'Detail Order',
        description:
            'Halaman detail order berisi:\n\n'
            '- Daftar item yang dibeli beserta jumlah dan harga\n'
            '- Biaya tambahan (pajak, service)\n'
            '- Diskon atau promosi yang digunakan\n'
            '- Metode dan detail pembayaran\n'
            '- Informasi terminal dan kasir\n\n'
            'Dari halaman ini Anda bisa mencetak ulang struk.',
        illustration: ManualIllustrationType.orderDetail,
      ),
      ManualStep(
        title: 'Filter Order',
        description:
            'Gunakan filter untuk mempersempit pencarian:\n\n'
            '- Filter berdasarkan cabang (jika multi-cabang)\n'
            '- Filter berdasarkan terminal\n'
            '- Pilih rentang tanggal tertentu\n\n'
            'Fitur filter sangat berguna untuk mencari order spesifik '
            'di toko yang ramai.',
        illustration: ManualIllustrationType.orderFilter,
      ),
    ],
  ),

  // ── 5. Inventori ──
  ManualSection(
    id: 'inventory',
    title: 'Inventori',
    subtitle: 'Kelola stok barang',
    icon: Icons.inventory_2_rounded,
    color: AppColors.warningAmber,
    steps: [
      ManualStep(
        title: 'Daftar Stok',
        description:
            'Halaman Inventori menampilkan semua produk beserta stoknya:\n\n'
            '- Produk dengan stok rendah diberi tanda warning\n'
            '- Stok habis ditandai dengan warna merah\n'
            '- Cari produk menggunakan kolom pencarian\n\n'
            'Tap produk untuk melihat detail riwayat pergerakan stok.',
        illustration: ManualIllustrationType.inventoryList,
      ),
      ManualStep(
        title: 'Restock (Barang Masuk)',
        description:
            'Untuk menambah stok barang yang baru datang:\n\n'
            '1. Tap tombol "Restock" di halaman Inventori\n'
            '2. Pilih produk yang akan direstock\n'
            '3. Masukkan jumlah barang yang masuk\n'
            '4. Tambahkan catatan (opsional)\n'
            '5. Tap "Simpan"\n\n'
            'Stok akan langsung bertambah setelah disimpan.',
        illustration: ManualIllustrationType.inventoryRestock,
      ),
      ManualStep(
        title: 'Adjustment (Koreksi Stok)',
        description:
            'Jika ada selisih stok fisik dan sistem:\n\n'
            '1. Tap "Adjustment" di halaman Inventori\n'
            '2. Pilih produk yang perlu dikoreksi\n'
            '3. Masukkan stok aktual (fisik)\n'
            '4. Sistem otomatis menghitung selisihnya\n'
            '5. Tambahkan alasan koreksi\n\n'
            'Riwayat adjustment tercatat untuk audit.',
        illustration: ManualIllustrationType.inventoryAdjustment,
      ),
      ManualStep(
        title: 'Laporan Inventory',
        description:
            'Laporan inventori menampilkan:\n\n'
            '- Ringkasan total SKU dan nilai stok\n'
            '- Daftar produk low-stock dan out-of-stock\n'
            '- Riwayat pergerakan stok (masuk, keluar, adjustment)\n'
            '- Grafik tren stok per periode\n\n'
            'Gunakan laporan ini untuk perencanaan pembelian.',
        illustration: ManualIllustrationType.inventoryReport,
      ),
      ManualStep(
        title: 'Detail Produk',
        description:
            'Tap produk di daftar inventori untuk melihat:\n\n'
            '- Stok saat ini dan lokasi penyimpanan\n'
            '- Riwayat lengkap pergerakan stok\n'
            '- Tanggal terakhir restock\n'
            '- Rata-rata penjualan harian\n\n'
            'Dari halaman ini Anda bisa langsung melakukan restock.',
        illustration: ManualIllustrationType.inventoryDetail,
      ),
    ],
  ),

  // ── 6. Absensi ──
  ManualSection(
    id: 'attendance',
    title: 'Absensi',
    subtitle: 'Catat kehadiran karyawan',
    icon: Icons.fingerprint_rounded,
    color: Colors.deepPurple,
    steps: [
      ManualStep(
        title: 'Masukkan PIN Karyawan',
        description:
            'Untuk memulai absensi, tap ikon fingerprint di AppBar dashboard '
            'atau tombol "Absensi" di header:\n\n'
            '1. Dialog numpad PIN akan muncul\n'
            '2. Masukkan PIN karyawan (4-6 digit)\n'
            '3. Sistem memverifikasi otomatis\n\n'
            'Fitur ini mendukung multi-user: banyak karyawan bisa absen '
            'dari satu device POS yang sama.',
        illustration: ManualIllustrationType.attendancePin,
      ),
      ManualStep(
        title: 'Geser untuk Absen',
        description:
            'Setelah PIN terverifikasi, halaman absensi menampilkan:\n\n'
            '- Status absensi hari ini (sudah masuk/belum)\n'
            '- Nama karyawan yang sedang absen\n'
            '- Tombol swipe: HIJAU untuk Masuk, MERAH untuk Pulang\n\n'
            'Geser tombol ke kanan untuk memulai proses absensi.',
        illustration: ManualIllustrationType.attendanceSwipe,
      ),
      ManualStep(
        title: 'Ambil Foto Wajah',
        description:
            'Setelah geser, kamera otomatis terbuka:\n\n'
            '- Kamera depan aktif untuk selfie\n'
            '- Posisikan wajah di tengah frame\n'
            '- Tap tombol "Ambil Foto"\n\n'
            'Foto akan disimpan di penyimpanan internal perangkat.',
        illustration: ManualIllustrationType.attendanceCamera,
      ),
      ManualStep(
        title: 'Konfirmasi & Lokasi GPS',
        description:
            'Setelah foto diambil, sistem otomatis mengambil data GPS:\n\n'
            '- Koordinat latitude/longitude ditampilkan\n'
            '- Alamat hasil reverse geocode (jika online)\n'
            '- Warning "MOCK GPS" jika terdeteksi fake GPS\n\n'
            'Tap "Konfirmasi" untuk menyimpan absensi.\n'
            'Tap "Ulangi" untuk ambil foto ulang.',
        illustration: ManualIllustrationType.attendanceConfirm,
      ),
      ManualStep(
        title: 'Riwayat Absensi',
        description:
            'Lihat riwayat absensi via ikon jam di kanan atas halaman absensi:\n\n'
            '- Dikelompokkan per tanggal\n'
            '- Setiap record menampilkan foto, waktu, tipe, alamat\n'
            '- Status pengiriman Telegram ditampilkan\n\n'
            'Data absensi otomatis dihapus setelah 7 hari untuk menghemat ruang.',
        illustration: ManualIllustrationType.attendanceHistory,
      ),
    ],
  ),

  // ── 7. Kitchen Display ──
  ManualSection(
    id: 'kitchen',
    title: 'Kitchen Display',
    subtitle: 'Tampilan order untuk dapur',
    icon: Icons.restaurant_rounded,
    color: AppColors.discountRed,
    steps: [
      ManualStep(
        title: 'Akses Kitchen Display',
        description:
            'Kitchen Display hanya bisa diakses oleh user dengan role "Kitchen".\n\n'
            'Login dengan PIN yang memiliki role Kitchen, dan Anda akan '
            'langsung diarahkan ke halaman Kitchen Display.\n\n'
            'Admin/Owner dapat membuat akun Kitchen di menu Settings > Users.',
        illustration: ManualIllustrationType.kitchenRole,
      ),
      ManualStep(
        title: 'Lihat Antrian Order',
        description:
            'Kitchen Display menampilkan semua order aktif secara real-time:\n\n'
            '- Setiap kartu order menampilkan nomor order dan daftar item\n'
            '- Item dikategorikan untuk memudahkan persiapan\n'
            '- Tampilan otomatis refresh setiap 30 detik\n\n'
            'Ini membantu staff dapur melihat pesanan tanpa perlu komunikasi manual.',
        illustration: ManualIllustrationType.kitchenDisplay,
      ),
      ManualStep(
        title: 'Update Status Order',
        description:
            'Setiap order di Kitchen Display dapat diperbarui statusnya:\n\n'
            '- Tap order yang sedang diproses\n'
            '- Tandai item yang sudah selesai\n'
            '- Order yang selesai akan otomatis hilang dari antrian\n\n'
            'Ini memastikan dapur dan kasir selalu sinkron.',
        illustration: ManualIllustrationType.kitchenStatus,
      ),
    ],
  ),

  // ── 8. Laporan ──
  ManualSection(
    id: 'reports',
    title: 'Laporan',
    subtitle: 'Analisis penjualan dan sesi',
    icon: Icons.assessment_rounded,
    color: AppColors.infoBlue,
    steps: [
      ManualStep(
        title: 'Laporan Sesi Kasir',
        description:
            'Laporan Sesi menampilkan riwayat buka/tutup register:\n\n'
            '- Tanggal dan waktu buka/tutup\n'
            '- Saldo awal dan akhir\n'
            '- Total penjualan selama sesi\n'
            '- Selisih kas (surplus/defisit)\n\n'
            'Tap sesi untuk melihat detail lengkap.',
        illustration: ManualIllustrationType.reportSession,
      ),
      ManualStep(
        title: 'Detail Sesi',
        description:
            'Halaman detail sesi menampilkan:\n\n'
            '- Ringkasan penjualan per metode pembayaran\n'
            '- Daftar semua order dalam sesi tersebut\n'
            '- Nama kasir dan terminal yang digunakan\n'
            '- Selisih kas dan catatan\n\n'
            'Gunakan data ini untuk evaluasi kinerja kasir.',
        illustration: ManualIllustrationType.reportSessionDetail,
      ),
      ManualStep(
        title: 'Laporan Penjualan',
        description:
            'Laporan Penjualan menampilkan tren dan analisis:\n\n'
            '- Grafik penjualan harian/mingguan/bulanan\n'
            '- Produk terlaris dan terendah\n'
            '- Revenue per kategori produk\n'
            '- Perbandingan periode sebelumnya\n\n'
            'Gunakan insight ini untuk keputusan bisnis.',
        illustration: ManualIllustrationType.reportSales,
      ),
      ManualStep(
        title: 'Filter Laporan',
        description:
            'Semua laporan mendukung filter:\n\n'
            '- Pilih cabang tertentu (jika multi-store)\n'
            '- Pilih terminal spesifik\n'
            '- Atur rentang tanggal\n\n'
            'Filter berlaku di semua tab laporan secara konsisten.',
        illustration: ManualIllustrationType.reportFilter,
      ),
    ],
  ),

  // ── 9. Master Data ──
  ManualSection(
    id: 'master_data',
    title: 'Master Data',
    subtitle: 'Kelola produk, user, dan referensi',
    icon: Icons.dataset_rounded,
    color: AppColors.primaryOrange,
    steps: [
      ManualStep(
        title: 'Kelola Produk',
        description:
            'Buka Settings > Products untuk mengelola katalog:\n\n'
            '- Tambah produk baru: nama, harga, kategori, barcode\n'
            '- Edit atau nonaktifkan produk\n'
            '- Konfigurasi produk Combo (paket bundel)\n'
            '- Konfigurasi BOM (Bill of Materials / resep)\n'
            '- Cetak label barcode untuk rak\n\n'
            'Perubahan produk langsung berlaku di POS.',
        illustration: ManualIllustrationType.masterProductForm,
      ),
      ManualStep(
        title: 'Kelola Kategori',
        description:
            'Buka Settings > Categories untuk mengorganisir produk:\n\n'
            '- Buat kategori baru (misal: Makanan, Minuman, Snack)\n'
            '- Edit atau hapus kategori\n'
            '- Kategori digunakan sebagai filter di halaman POS\n\n'
            'Produk tanpa kategori tetap tampil di katalog POS.',
        illustration: ManualIllustrationType.masterCategory,
      ),
      ManualStep(
        title: 'Kelola User',
        description:
            'Buka Settings > Users untuk mengelola akun pengguna:\n\n'
            '- Tambah user baru dengan nama, PIN, dan role\n'
            '- Assign ke terminal tertentu (untuk kasir)\n'
            '- Assign ke cabang tertentu\n'
            '- Aktifkan/nonaktifkan akses absensi\n'
            '- Deactivate user yang sudah tidak aktif\n\n'
            'Setiap user harus memiliki PIN unik.',
        illustration: ManualIllustrationType.masterUserForm,
      ),
      ManualStep(
        title: 'Metode Pembayaran',
        description:
            'Buka Settings > Payment Methods untuk mengatur:\n\n'
            '- Tambah metode pembayaran (Cash, QRIS, Transfer, Kartu, dll)\n'
            '- Aktifkan/nonaktifkan metode tertentu\n'
            '- Atur urutan tampil di halaman pembayaran\n\n'
            'Minimal satu metode pembayaran harus aktif.',
        illustration: ManualIllustrationType.masterPaymentMethod,
      ),
      ManualStep(
        title: 'Pricelist & Promosi',
        description:
            'Atur harga khusus dan promosi di Settings:\n\n'
            '- Pricelist: harga berbeda per cabang/waktu\n'
            '- Promosi: diskon persentase atau nominal\n'
            '- Biaya tambahan: pajak, service charge\n\n'
            'Promosi aktif otomatis diterapkan di POS saat checkout.',
        illustration: ManualIllustrationType.masterPricelist,
      ),
      ManualStep(
        title: 'Pelanggan',
        description:
            'Buka Settings > Customers untuk mengelola data pelanggan:\n\n'
            '- Tambah data pelanggan: nama, telepon, alamat\n'
            '- Pelanggan bisa dipilih saat transaksi POS\n'
            '- Riwayat pembelian pelanggan tercatat\n\n'
            'Data pelanggan bersifat opsional untuk setiap transaksi.',
        illustration: ManualIllustrationType.masterCustomer,
      ),
    ],
  ),

  // ── 10. Pengaturan ──
  ManualSection(
    id: 'settings',
    title: 'Pengaturan',
    subtitle: 'Konfigurasi toko dan integrasi',
    icon: Icons.settings_rounded,
    color: AppColors.textSecondary,
    steps: [
      ManualStep(
        title: 'Pengaturan Toko',
        description:
            'Buka Settings > Store Settings untuk mengatur info toko:\n\n'
            '- Nama toko, alamat, dan no. telepon\n'
            '- Header dan footer struk custom\n'
            '- Logo toko (opsional)\n\n'
            'Informasi ini ditampilkan di struk dan laporan Telegram.',
        illustration: ManualIllustrationType.settingsStore,
      ),
      ManualStep(
        title: 'Printer Bluetooth',
        description:
            'Buka Settings > Printer untuk koneksi printer:\n\n'
            '1. Nyalakan Bluetooth dan printer thermal\n'
            '2. Scan perangkat di halaman Printer Settings\n'
            '3. Pilih printer dari daftar yang muncul\n'
            '4. Tap "Connect" untuk menghubungkan\n'
            '5. Test print untuk memastikan koneksi berhasil\n\n'
            'Mendukung printer thermal 58mm via Bluetooth.',
        illustration: ManualIllustrationType.settingsPrinter,
      ),
      ManualStep(
        title: 'Integrasi Telegram',
        description:
            'Buka Settings > Telegram untuk menghubungkan bot:\n\n'
            '1. Buat bot Telegram via @BotFather\n'
            '2. Salin Bot Token ke kolom yang tersedia\n'
            '3. Masukkan Chat ID tujuan\n'
            '4. Tap "Test" untuk verifikasi\n\n'
            'Telegram digunakan untuk menerima laporan tutup kasir, '
            'absensi karyawan, dan notifikasi penting.',
        illustration: ManualIllustrationType.settingsTelegram,
      ),
      ManualStep(
        title: 'LAN Sync',
        description:
            'LAN Sync memungkinkan sinkronisasi data antar perangkat dalam '
            'satu jaringan WiFi:\n\n'
            '- Perangkat utama: aktifkan mode "Server"\n'
            '- Perangkat lain: aktifkan mode "Client" dan masukkan IP server\n'
            '- Data order, produk, dan sesi akan tersinkronisasi\n\n'
            'Kedua perangkat harus terhubung ke WiFi yang sama.',
        illustration: ManualIllustrationType.settingsLanSync,
      ),
      ManualStep(
        title: 'Cabang, Terminal, & Role',
        description:
            'Owner/Admin dapat mengelola struktur organisasi:\n\n'
            '- Cabang: buat dan kelola toko cabang di bawah HQ\n'
            '- Terminal: register/mesin kasir per cabang\n'
            '- Role: atur hak akses granular per role\n\n'
            'Fitur multi-cabang memungkinkan satu owner mengelola '
            'banyak lokasi dari satu akun.',
        illustration: ManualIllustrationType.settingsBranch,
      ),
    ],
  ),

  // ── 11. Data Demo ──
  ManualSection(
    id: 'demo_data',
    title: 'Data Demo',
    subtitle: 'Coba fitur dengan data contoh',
    icon: Icons.science_rounded,
    color: Colors.deepPurple,
    steps: [
      ManualStep(
        title: 'Muat Data Demo',
        description:
            'Buka Settings > Data Demo > "Muat Data Demo Multi-Cabang":\n\n'
            'Sistem akan membuat:\n'
            '- 3 toko (HQ + 2 cabang)\n'
            '- 5 terminal POS\n'
            '- Katalog produk lengkap + combo + resep\n'
            '- Pricelist, promosi, biaya, pelanggan\n'
            '- ~19 transaksi demo\n\n'
            'Data demo TIDAK menimpa data yang sudah ada.',
        illustration: ManualIllustrationType.demoDataLoad,
      ),
      ManualStep(
        title: 'PIN Demo',
        description:
            'Setelah data demo dimuat, gunakan PIN berikut:\n\n'
            '- 9999: Owner Kompak (HQ)\n'
            '- 1111: Admin HQ\n'
            '- 2222: Budi / Kasir Selatan 1\n'
            '- 3333: Sari / Kasir Selatan 2\n'
            '- 4444: Andi / Kasir Timur 1\n'
            '- 5555: Dewi / Kasir Timur 2\n\n'
            'Login dengan PIN berbeda untuk melihat tampilan per role.',
        illustration: ManualIllustrationType.demoDataPin,
      ),
      ManualStep(
        title: 'Uji Coba Fitur',
        description:
            'Setelah login dengan PIN demo, coba fitur-fitur berikut:\n\n'
            '- Buat transaksi POS dan cetak struk\n'
            '- Lihat dashboard dan laporan\n'
            '- Kelola inventori (restock/adjustment)\n'
            '- Absensi karyawan dari beberapa akun\n'
            '- Bandingkan tampilan Owner vs Kasir vs Kitchen\n\n'
            'Data demo bisa dihapus dengan reinstall aplikasi.',
        illustration: ManualIllustrationType.demoDataTest,
      ),
    ],
  ),
];
