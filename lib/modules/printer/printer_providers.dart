import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart'
    if (dart.library.html) '../../core/utils/bluetooth_stub.dart';
import '../core_providers.dart';

final printerConnectedProvider = StateProvider<bool>((ref) => false);

final connectedPrinterNameProvider = StateProvider<String?>((ref) => null);

final availablePrintersProvider =
    FutureProvider<List<BluetoothInfo>>((ref) async {
  if (kIsWeb) return []; // Bluetooth not available on web
  final service = ref.watch(printerServiceProvider);
  return service.scanDevices();
});

final printerAutoReconnectProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) return false; // No auto-reconnect on web
  final service = ref.read(printerServiceProvider);
  final success = await service.tryAutoReconnect();
  if (success) {
    ref.read(printerConnectedProvider.notifier).state = true;
    ref.read(connectedPrinterNameProvider.notifier).state =
        service.savedPrinterName;
  }
  return success;
});
