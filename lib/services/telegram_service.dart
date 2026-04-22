import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/daos/pos_session_dao.dart';
import '../core/utils/formatters.dart';
import '../models/session_report_model.dart';

class TelegramService {
  final SharedPreferences _prefs;
  final Dio _dio;

  static const _prefBotToken = 'telegram_bot_token';
  static const _prefChatId = 'telegram_chat_id';
  static const _prefEnabled = 'telegram_enabled';

  TelegramService({
    required SharedPreferences prefs,
  })  : _prefs = prefs,
        _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  bool get isEnabled => _prefs.getBool(_prefEnabled) ?? false;
  String get _token => _prefs.getString(_prefBotToken) ?? '';
  String get _chatId => _prefs.getString(_prefChatId) ?? '';

  /// Exposed for backup service to send documents directly.
  String get tokenForBackup => _token;
  String get chatIdForBackup => _chatId;

  String _baseUrl(String method) =>
      'https://api.telegram.org/bot$_token/$method';

  /// Send formatted session close report to Telegram
  Future<void> sendSessionReport({
    required SessionReport report,
    required String storeName,
    required String terminalName,
    required List<TopProductResult> topProducts,
  }) async {
    final message = _buildReportMessage(
      report: report,
      storeName: storeName,
      terminalName: terminalName,
      topProducts: topProducts,
    );

    await _withRetry(() => _dio.post(
          _baseUrl('sendMessage'),
          data: {
            'chat_id': _chatId,
            'text': message,
            'parse_mode': 'HTML',
          },
        ));
  }

  /// Send CSV file via Telegram
  Future<void> sendSessionCsv(File csvFile) async {
    final formData = FormData.fromMap({
      'chat_id': _chatId,
      'document': await MultipartFile.fromFile(
        csvFile.path,
        filename: csvFile.path.split('/').last,
      ),
      'caption': 'Detail transaksi sesi kasir',
    });

    await _withRetry(() => _dio.post(
          _baseUrl('sendDocument'),
          data: formData,
        ));
  }

  /// Test connection by sending a test message
  Future<bool> testConnection() async {
    if (_token.isEmpty || _chatId.isEmpty) return false;
    try {
      final response = await _dio.post(
        _baseUrl('sendMessage'),
        data: {
          'chat_id': _chatId,
          'text': '✅ Kompak POS terhubung!',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _buildReportMessage({
    required SessionReport report,
    required String storeName,
    required String terminalName,
    required List<TopProductResult> topProducts,
  }) {
    final date = Formatters.dateTime(report.closedAt ?? DateTime.now());
    final buf = StringBuffer();

    buf.writeln('<b>📊 LAPORAN TUTUP KASIR</b>');
    buf.writeln('');
    buf.writeln('🏪 $storeName');
    buf.writeln('📅 $date');
    buf.writeln('🖥️ Terminal: $terminalName');
    buf.writeln('👤 Kasir: ${report.cashierName}');
    buf.writeln('');
    buf.writeln('━━━━━━━━━━━━━━');
    buf.writeln('');
    buf.writeln('💰 <b>Total Penjualan</b>');
    buf.writeln(Formatters.currency(report.totalSales));
    buf.writeln('');
    buf.writeln('🧾 <b>Jumlah Transaksi</b>');
    buf.writeln('${report.totalOrders} transaksi');
    buf.writeln('');
    buf.writeln('━━━━━━━━━━━━━━');
    buf.writeln('');
    buf.writeln('💵 <b>Pembayaran</b>');
    for (final b in report.activeBreakdowns) {
      final net = b.totalAmount - b.totalChange;
      buf.writeln('• ${b.method}: ${Formatters.currency(net)} (${b.count}x)');
    }

    if (topProducts.isNotEmpty) {
      buf.writeln('');
      buf.writeln('━━━━━━━━━━━━━━');
      buf.writeln('');
      buf.writeln('📦 <b>Top Produk</b>');
      for (var i = 0; i < topProducts.length; i++) {
        final p = topProducts[i];
        buf.writeln('${i + 1}. ${p.productName} — ${p.totalQty}x');
      }
    }

    return buf.toString();
  }

  /// Send attendance photo with caption to Telegram
  Future<void> sendAttendancePhoto({
    required String photoPath,
    required String cashierName,
    required String storeName,
    required String type, // 'clock_in' | 'clock_out'
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required bool isMockLocation,
    String address = '',
  }) async {
    final typeLabel = type == 'clock_in' ? '✅ Masuk' : '🔴 Pulang';
    final dateStr = '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
    final mapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final mockWarning = isMockLocation ? 'Ya ⚠️' : 'Tidak';

    final addressLine = address.isNotEmpty
        ? '🏠 Alamat: $address\n'
        : '';

    final caption = '<b>📋 ABSENSI KASIR</b>\n\n'
        '👤 Nama: $cashierName\n'
        '🏪 Toko: $storeName\n'
        '📌 Tipe: $typeLabel\n'
        '🕐 Waktu: $dateStr\n\n'
        '━━━━━━━━━━━━━━\n\n'
        '$addressLine'
        '📍 Maps: $mapsLink\n'
        '🧭 Koordinat: $latitude, $longitude\n\n'
        '⚠️ Mock Location: $mockWarning';

    final formData = FormData.fromMap({
      'chat_id': _chatId,
      'photo': await MultipartFile.fromFile(photoPath),
      'caption': caption,
      'parse_mode': 'HTML',
    });

    await _withRetry(() => _dio.post(
          _baseUrl('sendPhoto'),
          data: formData,
        ));
  }

  /// Retry up to 3 times with exponential backoff
  Future<Response> _withRetry(Future<Response> Function() request) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Unreachable');
  }
}
