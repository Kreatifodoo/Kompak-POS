import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;
import '../core/constants/storage_keys.dart';
import '../core/database/app_database.dart';
import '../core/utils/logger.dart';

// Platform-specific imports — guarded by kIsWeb at runtime
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart'
    if (dart.library.html) '../core/utils/bluetooth_stub.dart';

class PrinterService {
  final SharedPreferences _prefs;
  bool _isConnected = false;

  PrinterService(this._prefs);

  bool get isConnected => _isConnected;

  /// Whether printing is supported (Bluetooth on mobile, browser print on web)
  bool get isPrintingSupported => !kIsWeb || true; // web uses browser print

  // ── Permission Handling ──

  Future<bool> requestBluetoothPermissions() async {
    if (kIsWeb) return false; // Bluetooth not supported on web
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    if (!allGranted) {
      AppLogger.warning('Bluetooth permissions not granted: $statuses');
    }
    return allGranted;
  }

  Future<bool> arePermissionsGranted() async {
    if (kIsWeb) return false;
    final connectStatus = await Permission.bluetoothConnect.status;
    final scanStatus = await Permission.bluetoothScan.status;
    return (connectStatus.isGranted || connectStatus.isLimited) &&
        (scanStatus.isGranted || scanStatus.isLimited);
  }

  // ── Device Scanning ──

  Future<List<BluetoothInfo>> scanDevices() async {
    if (kIsWeb) return []; // No Bluetooth scanning on web
    try {
      final hasPerms = await requestBluetoothPermissions();
      if (!hasPerms) {
        AppLogger.warning('Cannot scan: Bluetooth permissions denied');
        return [];
      }
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices;
    } catch (e) {
      AppLogger.error('Failed to scan devices', e);
      return [];
    }
  }

  // ── Connection ──

  Future<bool> connect(String macAddress) async {
    if (kIsWeb) return false;
    try {
      final hasPerms = await requestBluetoothPermissions();
      if (!hasPerms) return false;

      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      _isConnected = result;

      if (result) {
        // Let Bluetooth hardware settle before declaring ready
        await Future.delayed(const Duration(milliseconds: 500));
        await _prefs.setString(StorageKeys.printerAddress, macAddress);
      }
      return result;
    } catch (e) {
      AppLogger.error('Failed to connect to printer', e);
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb) return;
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      await _prefs.remove(StorageKeys.printerAddress);
      await _prefs.remove(StorageKeys.printerName);
    } catch (e) {
      AppLogger.error('Failed to disconnect printer', e);
    }
  }

  // ── Auto-Reconnect ──

  Future<bool> tryAutoReconnect() async {
    if (kIsWeb) return false;
    final savedAddress = _prefs.getString(StorageKeys.printerAddress);
    if (savedAddress == null) return false;

    final hasPerms = await arePermissionsGranted();
    if (!hasPerms) return false;

    try {
      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: savedAddress,
      );
      if (result) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _isConnected = result;
      return result;
    } catch (e) {
      AppLogger.error('Auto-reconnect failed', e);
      _isConnected = false;
      return false;
    }
  }

  String? get savedPrinterName => _prefs.getString(StorageKeys.printerName);
  String? get savedPrinterAddress =>
      _prefs.getString(StorageKeys.printerAddress);

  Future<void> savePrinterName(String name) async {
    await _prefs.setString(StorageKeys.printerName, name);
  }

  /// Save printer config to Terminal record in database.
  /// Called after a successful Bluetooth connect when a terminal is assigned.
  Future<void> savePrinterToTerminal({
    required AppDatabase db,
    required String terminalId,
    required String? address,
    required String? name,
  }) async {
    try {
      final terminal = await db.terminalDao.getById(terminalId);
      if (terminal != null) {
        await db.terminalDao.updateTerminal(TerminalsCompanion(
          id: Value(terminal.id),
          storeId: Value(terminal.storeId),
          name: Value(terminal.name),
          code: Value(terminal.code),
          isActive: Value(terminal.isActive),
          printerAddress: Value(address),
          printerName: Value(name),
          createdAt: Value(terminal.createdAt),
        ));
        AppLogger.info('Saved printer to terminal $terminalId: $name ($address)');
      }
    } catch (e) {
      AppLogger.error('Failed to save printer to terminal', e);
    }
  }

  // ── Printing ──

  Future<bool> checkConnection() async {
    if (kIsWeb) return false;
    try {
      _isConnected = await PrintBluetoothThermal.connectionStatus;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Ensures the printer is reachable, reconnecting if needed.
  /// Returns true only when a verified live connection exists.
  Future<bool> ensureConnected() async {
    if (kIsWeb) return false; // Web uses browser print dialog

    // 1. Check current live status
    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        _isConnected = true;
        return true;
      }
    } catch (_) {}

    // 2. Try reconnect from saved address
    final savedAddr = _prefs.getString(StorageKeys.printerAddress);
    if (savedAddr == null) {
      _isConnected = false;
      return false;
    }

    try {
      AppLogger.info('Reconnecting to printer $savedAddr ...');
      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: savedAddr,
      );
      if (!ok) {
        _isConnected = false;
        return false;
      }

      // Give BT hardware time to fully establish the channel
      await Future.delayed(const Duration(milliseconds: 1000));

      // 3. Verify the connection is actually alive after settle
      final verified = await PrintBluetoothThermal.connectionStatus;
      _isConnected = verified;
      AppLogger.info('Reconnect verified: $verified');
      return verified;
    } catch (e) {
      AppLogger.error('Reconnect failed', e);
      _isConnected = false;
      return false;
    }
  }

  /// Send bytes to the printer.
  /// IMPORTANT: sends ALL bytes in a single writeBytes call.
  /// Chunking breaks ESC/POS multi-byte commands and causes silent failures.
  Future<bool> printReceipt(List<int> bytes) async {
    if (kIsWeb) {
      AppLogger.warning('Bluetooth printing not available on web');
      return false;
    }
    try {
      // Verify connection is live before sending
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        AppLogger.warning('Printer not connected at print time');
        return false;
      }

      // Send ALL bytes at once — this is how print_bluetooth_thermal works.
      // The native Android layer handles buffering internally.
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      AppLogger.info('writeBytes result: $result (${bytes.length} bytes)');
      return result;
    } catch (e) {
      AppLogger.error('printReceipt exception', e);
      return false;
    }
  }

  // ── Test Print (proper ESC/POS) ──

  Future<List<int>> generateTestPrint() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // IMPORTANT: reset/init the printer first
    bytes += generator.reset();

    bytes += generator.text(
      'TEST PRINT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.hr();
    bytes += generator.text(
      'Kompak POS',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Printer is working!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.text(
      'Thank you',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Ultra-simple raw bytes test — bypasses ESC/POS generator entirely.
  /// If this prints "HELLO" on the paper, the BT connection is working.
  Future<bool> printRawTest() async {
    if (kIsWeb) return false;
    try {
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) return false;

      // Raw ESC/POS:  ESC @ (init) + "HELLO\n" + LF x3
      final List<int> raw = [
        0x1B, 0x40, // ESC @ — initialize printer
        0x1B, 0x61, 0x01, // ESC a 1 — center align
        0x48, 0x45, 0x4C, 0x4C, 0x4F, // "HELLO"
        0x0A, // line feed
        0x1B, 0x61, 0x00, // ESC a 0 — left align
        0x42, 0x50, 0x2D, 0x45, 0x43, 0x4F, 0x35, 0x38, // "BP-ECO58"
        0x0A, // line feed
        0x4B, 0x6F, 0x6D, 0x70, 0x61, 0x6B, 0x20, 0x50, 0x4F, 0x53, // "Kompak POS"
        0x0A, // line feed
        0x0A, 0x0A, 0x0A, // 3 extra line feeds to advance paper
      ];

      final result = await PrintBluetoothThermal.writeBytes(raw);
      AppLogger.info('Raw test print result: $result');
      return result;
    } catch (e) {
      AppLogger.error('Raw test print failed', e);
      return false;
    }
  }
}
