import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import 'csv_export_service.dart';
import 'pos_query_service.dart';

/// Intent detection result with optional product name and time period.
class IntentResult {
  final String intent;
  final String? productName;
  final String? timePeriod;
  IntentResult(this.intent, {this.productName, this.timePeriod});
}

/// Telegram chatbot that polls for messages, queries local POS data,
/// uses ChatGPT (OpenAI) to format natural responses, and replies via Telegram.
///
/// This service holds a Timer — it MUST be kept as a singleton via the provider.
class TelegramChatbotService {
  final SharedPreferences _prefs;
  final AppDatabase _db;
  final PosQueryService _queryService;
  final CsvExportService _csvService;
  final Dio _dio;
  final _log = Logger(printer: SimplePrinter());

  Timer? _pollTimer;
  int _lastUpdateId = 0;
  bool _isProcessing = false;

  static const _pollInterval = Duration(seconds: 5);
  static const _prefsLastUpdateKey = 'chatbot_last_update_id';

  /// OpenAI models to try in order — if one fails, fall back to next.
  static const _fallbackModels = [
    'gpt-4o-mini',
    'gpt-4o',
    'gpt-3.5-turbo',
  ];

  static const _openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';

  TelegramChatbotService({
    required SharedPreferences prefs,
    required AppDatabase db,
    required PosQueryService queryService,
    required CsvExportService csvService,
  })  : _prefs = prefs,
        _db = db,
        _queryService = queryService,
        _csvService = csvService,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        )) {
    // Restore last update ID from prefs so we don't reprocess old messages
    _lastUpdateId = _prefs.getInt(_prefsLastUpdateKey) ?? 0;
  }

  // ─── CONFIG ───────────────────────────────────────────────

  bool get isEnabled => _prefs.getBool('telegram_chatbot_enabled') ?? false;
  String get _botToken => _prefs.getString('telegram_bot_token')?.trim() ?? '';
  String get _chatId => _prefs.getString('telegram_chat_id')?.trim() ?? '';
  String get _openaiKey => _prefs.getString('openai_api_key')?.trim() ?? '';
  bool get isPolling => _pollTimer?.isActive ?? false;

  String _telegramUrl(String method) =>
      'https://api.telegram.org/bot$_botToken/$method';

  // ─── POLLING LIFECYCLE ────────────────────────────────────

  void startPolling() {
    if (_pollTimer?.isActive ?? false) {
      _log.i('Chatbot already polling, skipping startPolling()');
      return;
    }
    if (!isEnabled || _botToken.isEmpty || _openaiKey.isEmpty) {
      _log.w('Chatbot not starting: enabled=$isEnabled, '
          'hasToken=${_botToken.isNotEmpty}, hasOpenAI=${_openaiKey.isNotEmpty}');
      return;
    }

    _log.i('Chatbot polling started (lastUpdateId=$_lastUpdateId)');
    // Run first poll immediately, then every 5 seconds
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _log.i('Chatbot polling stopped');
  }

  /// Re-read config from SharedPreferences (call after settings save).
  void reloadConfig() {
    _lastUpdateId = _prefs.getInt(_prefsLastUpdateKey) ?? _lastUpdateId;
  }

  /// Send online/offline status notification to Telegram chat.
  Future<void> sendStatusNotification({required bool online}) async {
    if (_botToken.isEmpty || _chatId.isEmpty) return;
    try {
      if (online) {
        await _sendTelegram(
          _chatId,
          '🟢 Kompak POS Online\n'
          'Device aktif, bot siap menerima pertanyaan.\n\n'
          'Ketik pertanyaan seperti:\n'
          '- "Penjualan hari ini?"\n'
          '- "Top produk?"\n'
          '- "Cek stok"',
        );
      } else {
        await _sendTelegram(
          _chatId,
          '🔴 Kompak POS Offline\n'
          'Device tidak aktif. Pesan yang dikirim saat offline '
          'akan dijawab otomatis saat device aktif kembali.',
        );
      }
    } catch (e) {
      _log.e('Failed to send status notification: $e');
    }
  }

  // ─── POLL LOGIC ───────────────────────────────────────────

  Future<void> _poll() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final response = await _dio.get(
        _telegramUrl('getUpdates'),
        queryParameters: {
          'offset': _lastUpdateId + 1,
          'timeout': 1,
          'allowed_updates': ['message'],
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] != true) {
        _log.w('getUpdates returned ok=false: $data');
        return;
      }

      final updates = (data['result'] as List<dynamic>?) ?? [];
      if (updates.isNotEmpty) {
        _log.i('Received ${updates.length} updates');
      }

      for (final update in updates) {
        final updateId = update['update_id'] as int;
        _lastUpdateId = updateId;
        // Persist so we don't re-process on app restart
        await _prefs.setInt(_prefsLastUpdateKey, _lastUpdateId);

        final message = update['message'] as Map<String, dynamic>?;
        if (message == null) continue;

        final text = message['text'] as String?;
        final chatId = message['chat']?['id']?.toString().trim();
        if (text == null || chatId == null) continue;

        // Only respond to messages from the configured chat
        if (chatId != _chatId) {
          _log.w('Ignoring message from chatId=$chatId (expected=$_chatId)');
          continue;
        }

        _log.i('Processing message: "$text"');
        await _handleMessage(chatId, text);
      }
    } on DioException catch (e) {
      _log.e('Polling DioError: ${e.type} - ${e.message}');
    } catch (e) {
      _log.e('Polling error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ─── MESSAGE HANDLING ─────────────────────────────────────

  Future<void> _handleMessage(String chatId, String userText) async {
    try {
      final result = await _classifyIntent(userText);
      _log.i('Classified intent: ${result.intent}, product: ${result.productName}, period: ${result.timePeriod}');

      final storeId = await _getCurrentStoreId();
      if (storeId == null) {
        await _sendTelegram(chatId, 'Tidak ada toko aktif di device ini.');
        return;
      }

      // Handle export intents — generate CSV and send file
      if (result.intent.startsWith('export_')) {
        await _handleExportIntent(chatId, result, storeId);
        return;
      }

      final dataContext = await _queryService.queryByIntent(
        result.intent,
        storeId,
        productName: result.productName,
        timePeriod: result.timePeriod,
      );
      _log.i('Query result length: ${dataContext.length}');

      final aiResponse = await _askChatGPT(userText, dataContext);
      await _sendTelegram(chatId, aiResponse);
      _log.i('Response sent successfully');
    } catch (e) {
      _log.e('Handle message error: $e');
      await _sendTelegram(chatId, 'Maaf, terjadi kesalahan: $e');
    }
  }

  // ─── INTENT DETECTION ─────────────────────────────────────

  /// Detects intent and optionally extracts product name from user text.
  IntentResult detectIntent(String text) {
    // FIX BUG #5: Normalize whitespace so "penjualan  hari   ini" still matches
    final lower = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    // ══ STEP 0: EXPORT INTENTS — check BEFORE all other intents ══
    if (_matchesAny(lower, ['export sesi', 'download sesi', 'csv sesi', 'excel sesi', 'unduh sesi', 'kirim file sesi', 'export session'])) {
      return IntentResult('export_session');
    }
    if (_matchesAny(lower, ['export penjualan', 'download penjualan', 'csv penjualan', 'excel penjualan', 'unduh penjualan', 'export sales', 'kirim file penjualan'])) {
      return IntentResult('export_sales');
    }
    if (_matchesAny(lower, ['export inventory', 'download inventory', 'csv inventory', 'export stok', 'csv stok', 'excel stok', 'unduh stok', 'unduh inventory', 'kirim file stok'])) {
      return IntentResult('export_inventory');
    }
    if (_matchesAny(lower, ['export dashboard', 'download dashboard', 'csv dashboard', 'excel dashboard', 'unduh dashboard', 'kirim file dashboard', 'export laporan', 'download laporan', 'csv laporan', 'excel laporan', 'unduh laporan'])) {
      return IntentResult('export_dashboard');
    }

    // ══ STEP 1: Guard — specific stock/inventory intents BEFORE greedy regex ══
    // FIX BUG #2: "stok rendah" was incorrectly matched as stock_search because
    // the greedy regex captured "rendah" as a product name. Check these first.
    if (_matchesAny(lower, ['stok rendah', 'stok habis', 'low stock', 'hampir habis', 'stock low'])) {
      return IntentResult('stock_low');
    }
    if (_matchesAny(lower, ['pergerakan stok', 'stock movement', 'mutasi stok', 'history stok', 'riwayat stok'])) {
      return IntentResult('stock_movements');
    }
    if (_matchesAny(lower, ['resep', 'recipe', 'bom', 'bahan baku', 'bill of material', 'komposisi'])) {
      return IntentResult('bom_info');
    }

    // ══ STEP 2: Check for STOCK + product name queries ══
    // e.g., "stock coreng isi tinggal berapa", "stok air mineral",
    // FIX BUG #3: "air mineral tinggal berapa" (no "stok" prefix) now handled
    // by _extractStockProductName which also checks pre-keyword patterns.
    final stockProductMatch = RegExp(
      r'(?:stok|stock|sisa|tinggal berapa)\s+(.+?)(?:\s+(?:tinggal|berapa|sisa|ada).*)?$',
    ).firstMatch(lower);
    if (stockProductMatch != null || _hasStockWithProduct(lower)) {
      final extracted = stockProductMatch?.group(1)?.trim();
      final productName = _cleanProductName(
        extracted ?? _extractStockProductName(lower),
      );
      if (productName.isNotEmpty) {
        return IntentResult('stock_search', productName: productName);
      }
    }

    // ══ STEP 3: Check for SALES + product name queries ══
    // e.g., "penjualan chicken wings dalam bulan ini", "jual cireng isi"
    if (_matchesAny(lower, ['penjualan', 'sales', 'jual', 'omset', 'laku'])) {
      final productName = _extractProductFromSalesQuery(lower);
      if (productName.isNotEmpty) {
        return IntentResult('product_sales', productName: productName);
      }
    }

    // ══ STEP 4: Standard intent matching (no product name) ══

    // ── Products — check alltime BEFORE all_sales to prevent keyword conflict ──
    // FIX BUG #1: "produk terlaris all time" was hitting 'all time' → all_sales
    // because all_sales was checked first. Now top_products_alltime is checked
    // before any 'all time' rule.
    if (_matchesAny(lower, [
      'top produk all', 'produk terlaris all', 'terlaris semua',
      'best seller all', 'top all time', 'terlaris all time',
      'produk terlaris all time', 'top produk sepanjang',
    ])) {
      return IntentResult('top_products_alltime');
    }
    if (_matchesAny(lower, ['top produk', 'produk terlaris', 'best seller', 'paling laku', 'terlaris', 'top product'])) {
      return IntentResult('top_products');
    }

    // ── Sales ──
    if (_matchesAny(lower, ['total penjualan', 'all time', 'keseluruhan', 'seluruh', 'dari awal', 'semua penjualan'])) {
      return IntentResult('all_sales');
    }
    if (_matchesAny(lower, ['penjualan hari ini', 'sales today', 'omset hari ini', 'pendapatan hari ini', 'jual hari ini'])) {
      return IntentResult('daily_sales');
    }
    if (_matchesAny(lower, ['penjualan minggu', 'sales week', 'omset minggu', 'mingguan'])) {
      return IntentResult('weekly_sales');
    }
    if (_matchesAny(lower, ['penjualan bulan', 'sales month', 'omset bulan', 'bulanan'])) {
      return IntentResult('monthly_sales');
    }
    if (_matchesAny(lower, ['tren penjualan', 'sales trend', 'tren', 'trend', 'grafik'])) {
      return IntentResult('sales_trend');
    }
    if (_matchesAny(lower, ['per kategori', 'category', 'kategori penjualan'])) {
      return IntentResult('sales_by_category');
    }

    // ── More Products ──
    if (_matchesAny(lower, ['combo', 'paket', 'bundling', 'bundle'])) {
      return IntentResult('combo_info');
    }
    if (_matchesAny(lower, ['pricelist', 'harga khusus', 'daftar harga', 'harga grosir'])) {
      return IntentResult('pricelist_info');
    }
    if (_matchesAny(lower, ['promosi', 'promo', 'diskon', 'discount', 'kupon', 'voucher'])) {
      return IntentResult('promotion_info');
    }

    // ── Inventory (general) ──
    if (_matchesAny(lower, ['stok', 'stock', 'inventori', 'inventory', 'persediaan'])) {
      return IntentResult('stock_check');
    }

    // ── Financial ──
    if (_matchesAny(lower, ['biaya', 'charges', 'pajak', 'tax', 'ppn', 'service charge'])) {
      return IntentResult('charges_info');
    }
    if (_matchesAny(lower, ['profit', 'laba', 'margin', 'keuntungan', 'hpp', 'cost'])) {
      return IntentResult('profit_report');
    }
    if (_matchesAny(lower, ['retur', 'return', 'refund', 'pengembalian'])) {
      return IntentResult('returns_info');
    }
    if (_matchesAny(lower, ['pembayaran semua', 'payment all', 'semua pembayaran', 'total pembayaran'])) {
      return IntentResult('payment_alltime');
    }
    if (_matchesAny(lower, ['pembayaran', 'payment', 'metode bayar', 'qris'])) {
      return IntentResult('payment_breakdown');
    }

    // ── Operational ──
    if (_matchesAny(lower, ['transaksi terakhir', 'order terakhir', 'recent', 'transaksi terbaru', 'riwayat transaksi'])) {
      return IntentResult('recent_orders');
    }
    if (_matchesAny(lower, ['performa kasir', 'kasir all', 'semua kasir', 'kinerja kasir all'])) {
      return IntentResult('cashier_alltime');
    }
    // FIX BUG #4: session_info now checked BEFORE cashier_stats so "sesi kasir"
    // correctly returns session_info instead of matching "kasir" → cashier_stats.
    if (_matchesAny(lower, ['sesi', 'session', 'shift', 'register'])) {
      return IntentResult('session_info');
    }
    if (_matchesAny(lower, ['kasir', 'cashier', 'kinerja kasir'])) {
      return IntentResult('cashier_stats');
    }
    if (_matchesAny(lower, ['terminal', 'mesin kasir', 'perangkat pos'])) {
      return IntentResult('terminal_info');
    }
    if (_matchesAny(lower, ['cabang', 'branch', 'toko', 'outlet', 'store'])) {
      return IntentResult('branch_info');
    }

    // ── CRM ──
    if (_matchesAny(lower, ['customer', 'pelanggan', 'member', 'loyalty', 'poin'])) {
      return IntentResult('customer_info');
    }

    // ── Summary ──
    if (_matchesAny(lower, ['ringkasan', 'summary', 'laporan', 'report', 'rangkuman', 'rekap'])) {
      return IntentResult('full_summary');
    }

    return IntentResult('full_summary');
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  /// Check if the query is asking about stock of a specific product.
  /// FIX BUG #3: also handles "air mineral tinggal berapa?" without "stok" prefix.
  bool _hasStockWithProduct(String text) {
    // Pattern: "X tinggal berapa", "X sisa berapa", "ada berapa X"
    final hasQuantityPhrase =
        RegExp(r'(.+?)\s+(?:tinggal|sisa)\s*(?:berapa)?').hasMatch(text) ||
        RegExp(r'(?:berapa|sisa|tinggal)\s+(?:stok|stock)\s+(.+)').hasMatch(text);
    return hasQuantityPhrase &&
        _matchesAny(text, ['stok', 'stock', 'tinggal', 'sisa', 'berapa']);
  }

  /// Extract product name from patterns like "air mineral tinggal berapa"
  /// where the product name comes BEFORE the quantity keyword.
  /// FIX BUG #3: fallback when no "stok/stock" prefix keyword is found.
  String _extractStockProductName(String text) {
    // Try "X tinggal/sisa berapa?" → extract X
    final preMatch = RegExp(
      r'^(.+?)\s+(?:tinggal|sisa)\b',
    ).firstMatch(text);
    if (preMatch != null) {
      return _cleanProductName(preMatch.group(1)?.trim() ?? '');
    }
    // Fallback: after stok/stock keyword
    return _extractAfterKeyword(text, ['stok', 'stock', 'sisa']);
  }

  /// Extract product name from sales queries like:
  /// "penjualan chicken wings dalam bulan ini" → "chicken wings"
  /// "jual cireng isi" → "cireng isi"
  String _extractProductFromSalesQuery(String text) {
    // Remove known keywords/modifiers to isolate product name
    var cleaned = text;
    const removeWords = [
      'penjualan', 'sales', 'jual', 'omset', 'laku', 'data', 'info', 'berapa',
      'hari ini', 'bulan ini', 'minggu ini', 'dalam bulan ini', 'dalam minggu ini',
      'bulan', 'minggu', 'hari', 'ini', 'dalam', 'dari', 'untuk',
      'total', 'semua', 'seluruh', 'keseluruhan',
      'today', 'month', 'week', 'this',
    ];
    for (final word in removeWords) {
      cleaned = cleaned.replaceAll(word, ' ');
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // If remaining text looks like a product name (2+ chars, not just noise)
    if (cleaned.length >= 2 && !_isGenericWord(cleaned)) {
      return cleaned;
    }
    return '';
  }

  /// Extract text after a keyword
  String _extractAfterKeyword(String text, List<String> keywords) {
    for (final kw in keywords) {
      final idx = text.indexOf(kw);
      if (idx >= 0) {
        return text.substring(idx + kw.length).trim();
      }
    }
    return '';
  }

  /// Clean extracted product name by removing trailing modifiers
  String _cleanProductName(String raw) {
    var cleaned = raw;
    const trailingWords = [
      'tinggal berapa', 'tinggal', 'berapa', 'sisa', 'ada', 'brp',
      'tersisa', 'masih', 'habis',
    ];
    for (final w in trailingWords) {
      cleaned = cleaned.replaceAll(RegExp('\\s*$w\\s*\$'), '');
    }
    return cleaned.trim();
  }

  /// Words that are NOT product names (generic query words)
  bool _isGenericWord(String word) {
    const genericWords = {
      'hari ini', 'hari', 'ini', 'bulan', 'minggu',
      'semua', 'total', 'berapa', 'mana', 'apa', 'siapa', 'kapan',
      'kemarin', 'lalu', 'nanti', 'sekarang', 'tadi', 'besok', 'dalam',
      'terlaris', 'terbanyak', 'tertinggi', 'terendah', 'dari',
      'today', 'week', 'month', 'all', 'time',
    };
    return genericWords.contains(word.trim());
  }

  // ─── OPENAI INTENT CLASSIFICATION ─────────────────────────

  /// Uses ChatGPT (OpenAI) to classify user intent, extract product name and time period.
  /// Falls back to keyword-based [detectIntent] if OpenAI fails.
  Future<IntentResult> _classifyIntent(String userText) async {
    if (_openaiKey.isEmpty) return detectIntent(userText);

    const systemPrompt = '''Kamu adalah classifier untuk sistem POS (Point of Sale).
Analisis pertanyaan user dan kembalikan HANYA JSON (tanpa penjelasan) dengan format:
{"intent": "...", "product_name": "...", "time_period": "..."}

VALID INTENTS (pilih SATU yang paling cocok):
- daily_sales: penjualan hari ini
- weekly_sales: penjualan minggu ini
- monthly_sales: penjualan bulan ini
- all_sales: total semua penjualan dari awal
- sales_by_category: penjualan per kategori
- sales_trend: tren/grafik penjualan
- top_products: produk terlaris
- top_products_alltime: produk terlaris sepanjang waktu
- product_sales: penjualan produk spesifik (isi product_name)
- combo_info: info paket/combo/bundling
- pricelist_info: daftar harga/harga khusus/grosir
- promotion_info: info promosi/diskon/promo
- stock_check: cek stok keseluruhan
- stock_search: cek stok produk spesifik (isi product_name)
- stock_low: stok rendah/hampir habis
- stock_movements: pergerakan/mutasi stok
- bom_info: resep/bahan baku/bill of material
- payment_breakdown: rincian pembayaran hari ini
- payment_alltime: rincian pembayaran keseluruhan
- charges_info: biaya/pajak/service charge
- profit_report: laba/margin/keuntungan
- returns_info: retur/refund
- recent_orders: transaksi terakhir/terbaru
- cashier_stats: performa kasir hari ini
- cashier_alltime: performa kasir keseluruhan
- session_info: info sesi/shift kasir
- terminal_info: info terminal/mesin kasir
- branch_info: info cabang/toko/outlet
- customer_info: info pelanggan/member
- full_summary: ringkasan/laporan umum
- export_session: export/download/unduh CSV laporan sesi kasir
- export_sales: export/download/unduh CSV laporan penjualan
- export_inventory: export/download/unduh CSV laporan inventory/stok
- export_dashboard: export/download/unduh CSV dashboard/ringkasan/laporan

VALID TIME_PERIOD (pilih SATU, atau null jika tidak disebutkan):
- today: hari ini
- yesterday: kemarin
- this_week: minggu ini
- last_week: minggu lalu/kemarin minggu
- this_month: bulan ini
- last_month: bulan lalu/kemarin bulan
- last_3_months: 3 bulan terakhir
- this_year: tahun ini
- all_time: dari awal/semua/keseluruhan/sepanjang waktu

RULES:
- product_name: isi nama produk jika user menyebut produk spesifik, null jika tidak
- time_period: isi jika user menyebut periode waktu, null jika tidak
- Pahami sinonim: "laku"="terjual", "omset"="penjualan", "barang"="produk", "sisa"="stok"
- Pahami typo ringan: "pnjualan"="penjualan", "stok"="stock"
- Jika ambigu, pilih intent yang paling umum (full_summary)
- HANYA kembalikan JSON, tanpa penjelasan''';

    for (final modelName in _fallbackModels) {
      try {
        final text = await _callOpenAI(
          systemPrompt,
          userText,
          model: modelName,
          maxTokens: 150,
          temperature: 0.1,
        );
        if (text == null || text.isEmpty) continue;

        // Parse JSON — handle markdown code blocks
        var jsonStr = text.trim();
        if (jsonStr.contains('```')) {
          jsonStr = jsonStr
              .replaceAll(RegExp(r'```json\s*'), '')
              .replaceAll(RegExp(r'```\s*'), '')
              .trim();
        }

        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final intent = json['intent'] as String? ?? 'full_summary';
        final productName = json['product_name'] as String?;
        final timePeriod = json['time_period'] as String?;

        _log.i('ChatGPT classified: intent=$intent, product=$productName, '
            'period=$timePeriod (model=$modelName)');

        return IntentResult(
          intent,
          productName: (productName != null && productName.isNotEmpty)
              ? productName
              : null,
          timePeriod: (timePeriod != null && timePeriod.isNotEmpty)
              ? timePeriod
              : null,
        );
      } catch (e) {
        _log.w('Classification model $modelName failed: $e');
        continue;
      }
    }

    // Fallback to keyword matching
    _log.i('ChatGPT classification failed, falling back to keyword matching');
    return detectIntent(userText);
  }

  // ─── OPENAI CHATGPT (with model fallback) ──────────────────

  /// Tries each model in [_fallbackModels] until one succeeds.
  /// If all fail, returns the raw data without AI formatting.
  Future<String> _askChatGPT(String userQuestion, String dataContext) async {
    const systemPrompt =
        'Kamu adalah Kompak AI, asisten POS cerdas untuk toko retail/F&B. '
        'Jawab berdasarkan DATA POS yang diberikan dalam bahasa Indonesia. '
        'Gunakan format Rupiah (Rp). Gunakan emoji yang relevan. '
        'Berikan insight bisnis: tren, perbandingan, saran jika relevan. '
        'Jika data mencakup histori, bandingkan performa antar periode. '
        'Jika ada data stok rendah, beri peringatan. '
        'Jika data kosong, katakan jujur. JANGAN mengarang data. '
        'Batasi jawaban maksimal 800 karakter agar mudah dibaca di Telegram.';

    final userPrompt =
        'Pertanyaan user: "$userQuestion"\n\nDATA POS:\n$dataContext';

    for (final modelName in _fallbackModels) {
      try {
        final text = await _callOpenAI(
          systemPrompt,
          userPrompt,
          model: modelName,
          maxTokens: 800,
          temperature: 0.3,
        );
        if (text != null && text.isNotEmpty) {
          _log.i('ChatGPT response via model: $modelName');
          return text;
        }
      } catch (e) {
        _log.w('Model $modelName failed: $e');
        continue;
      }
    }

    // All models failed — return raw data
    _log.e('All ChatGPT models failed, returning raw data');
    return dataContext;
  }

  // ─── OPENAI API HELPER ────────────────────────────────────

  /// Calls OpenAI Chat Completions API via Dio.
  /// Returns the assistant message content, or null on failure.
  Future<String?> _callOpenAI(
    String systemPrompt,
    String userPrompt, {
    String model = 'gpt-4o-mini',
    int maxTokens = 800,
    double temperature = 0.3,
  }) async {
    final response = await _dio
        .post(
          _openaiBaseUrl,
          options: Options(
            headers: {
              'Authorization': 'Bearer $_openaiKey',
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'max_tokens': maxTokens,
            'temperature': temperature,
          },
        )
        .timeout(const Duration(seconds: 30));

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  }

  // ─── CSV EXPORT HANDLING ───────────────────────────────────

  Future<void> _handleExportIntent(
    String chatId,
    IntentResult result,
    String storeId,
  ) async {
    try {
      await _sendTelegram(chatId, '📄 Sedang menyiapkan file CSV...');

      File csvFile;
      String caption;

      switch (result.intent) {
        case 'export_session':
          // Find latest closed session
          final sessions = await _db.customSelect(
            '''SELECT id, closed_at FROM pos_sessions
               WHERE store_id = ? AND status = 'closed'
               ORDER BY closed_at DESC LIMIT 1''',
            variables: [Variable.withString(storeId)],
            readsFrom: {_db.posSessions},
          ).get();
          if (sessions.isEmpty) {
            await _sendTelegram(chatId, '❌ Belum ada sesi kasir yang ditutup.');
            return;
          }
          final sessionId = sessions.first.read<String>('id');
          csvFile = await _csvService.generateSessionCsv(sessionId);
          caption = '📊 Laporan Sesi Kasir Terakhir';

        case 'export_sales':
          csvFile = await _csvService.generateSalesReportCsv(
            storeId,
            timePeriod: result.timePeriod,
          );
          caption = '📊 Laporan Penjualan (${result.timePeriod ?? "Keseluruhan"})';

        case 'export_inventory':
          csvFile = await _csvService.generateInventoryReportCsv(storeId);
          caption = '📦 Laporan Inventory';

        case 'export_dashboard':
          csvFile = await _csvService.generateDashboardCsv(
            storeId,
            timePeriod: result.timePeriod,
          );
          caption = '📈 Dashboard Ringkasan (${result.timePeriod ?? "Keseluruhan"})';

        default:
          await _sendTelegram(chatId, '❌ Tipe export tidak dikenal.');
          return;
      }

      await _sendDocument(chatId, csvFile, caption);
      _log.i('CSV file sent: ${csvFile.path}');

      // Clean up temp file
      try {
        await csvFile.delete();
      } catch (_) {}
    } catch (e) {
      _log.e('Export error: $e');
      await _sendTelegram(chatId, '❌ Gagal export: $e');
    }
  }

  /// Send a file document via Telegram Bot API.
  Future<void> _sendDocument(String chatId, File file, String caption) async {
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'document': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'caption': caption,
    });

    await _dio.post(
      _telegramUrl('sendDocument'),
      data: formData,
    );
  }

  // ─── TELEGRAM SEND ────────────────────────────────────────

  Future<void> _sendTelegram(String chatId, String text) async {
    try {
      await _dio.post(
        _telegramUrl('sendMessage'),
        data: {
          'chat_id': chatId,
          'text': text,
        },
      );
    } catch (e) {
      _log.e('Failed to send Telegram message: $e');
    }
  }

  // ─── TEST / DIAGNOSTIC ──────────────────────────────────

  /// Runs a full diagnostic: validates OpenAI API key, finds working model,
  /// queries POS data, and sends a test response via Telegram.
  Future<String> testChatbot() async {
    final results = StringBuffer();

    // 1. Check config
    if (_botToken.isEmpty) return '❌ Bot Token belum diisi.';
    if (_chatId.isEmpty) return '❌ Chat ID belum diisi.';
    if (_openaiKey.isEmpty) return '❌ OpenAI API Key belum diisi.';
    results.writeln('✅ Konfigurasi lengkap');

    // 2. Test OpenAI API — try each model
    String? workingModel;
    final failedModels = <String>[];

    for (final modelName in _fallbackModels) {
      try {
        final text = await _callOpenAI(
          'Jawab dengan satu kata saja.',
          'OK?',
          model: modelName,
          maxTokens: 10,
        );
        if (text != null && text.isNotEmpty) {
          workingModel = modelName;
          break;
        }
      } catch (e) {
        failedModels.add(modelName);
        _log.w('Test model $modelName failed: $e');
      }
    }

    if (workingModel != null) {
      results.writeln('✅ OpenAI API valid (model: $workingModel)');
      if (failedModels.isNotEmpty) {
        results.writeln(
            '⚠️ Model unavailable: ${failedModels.join(", ")}');
      }
    } else {
      results.writeln(
          '❌ Semua model OpenAI gagal (${failedModels.join(", ")})');
      results.writeln('💡 Cek API Key dan saldo di platform.openai.com');
      return results.toString();
    }

    // 3. Test POS data query
    try {
      final storeId = await _getCurrentStoreId();
      if (storeId == null) {
        return '$results❌ Tidak ada toko aktif di database.';
      }
      results.writeln('✅ Store ditemukan');

      final data = await _queryService.queryByIntent('daily_sales', storeId);
      results.writeln('✅ Query POS berhasil');
      results.writeln('📊 Preview data:\n$data');
    } catch (e) {
      return '$results❌ Query POS error: $e';
    }

    // 4. Test send Telegram message
    try {
      await _sendTelegram(
          _chatId,
          '🤖 Test AI Chatbot Kompak POS\n\n'
          'Koneksi berhasil! Model: $workingModel (OpenAI)\n'
          'Bot siap menerima pertanyaan.\n\n'
          'Coba tanya:\n'
          '- "Penjualan hari ini?"\n'
          '- "Top produk?"\n'
          '- "Cek stok"');
      results.writeln('✅ Pesan test terkirim ke Telegram');
    } catch (e) {
      return '$results❌ Gagal kirim ke Telegram: $e';
    }

    return results.toString();
  }

  // ─── HELPERS ──────────────────────────────────────────────

  Future<String?> _getCurrentStoreId() async {
    final stores = await _db.select(_db.stores).get();
    if (stores.isEmpty) return null;
    final hq = stores.where((s) => s.parentId == null).firstOrNull;
    return hq?.id ?? stores.first.id;
  }
}
