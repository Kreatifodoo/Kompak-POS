/// Web stub for print_bluetooth_thermal types.
/// All Bluetooth code paths are guarded by `if (kIsWeb)` at runtime,
/// so these stubs are never actually called — they exist only to satisfy
/// the dart2js compiler when building for web.

class BluetoothInfo {
  final String name;
  final String macAdress; // matches original package field spelling
  const BluetoothInfo(this.name, this.macAdress);
}

class PrintBluetoothThermal {
  static Future<List<BluetoothInfo>> get pairedBluetooths async => [];
  static Future<bool> connect({required String macPrinterAddress}) async =>
      false;
  static Future<void> get disconnect async {}
  static Future<bool> get connectionStatus async => false;
  static Future<bool> writeBytes(List<int> bytes) async => false;
}
