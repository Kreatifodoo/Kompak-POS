import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart'
    if (dart.library.html) '../../core/utils/bluetooth_stub.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../modules/printer/printer_providers.dart';
import '../../modules/core_providers.dart';
import '../../modules/terminal/terminal_providers.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState
    extends ConsumerState<PrinterSettingsScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerAutoReconnectProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Web: show browser print info instead of Bluetooth UI
    if (kIsWeb) return _buildWebPrinterSettings(context);

    final isConnected = ref.watch(printerConnectedProvider);
    final connectedName = ref.watch(connectedPrinterNameProvider);
    final devicesAsync = ref.watch(availablePrintersProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Printer Settings',
          style: AppTextStyles.heading3,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Terminal info banner
            if (ref.watch(currentTerminalProvider) != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.infoBlue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded,
                        color: AppColors.infoBlue, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terminal: ${ref.watch(currentTerminalProvider)!.name}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.infoBlue,
                            ),
                          ),
                          Text(
                            'Printer yang di-connect akan disimpan ke terminal ini',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.infoBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Connection status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.successGreen.withOpacity(0.1)
                          : AppColors.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.print_rounded
                          : Icons.print_disabled_rounded,
                      color: isConnected
                          ? AppColors.successGreen
                          : AppColors.errorRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: AppTextStyles.heading3.copyWith(
                            fontSize: 16,
                            color: isConnected
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                          ),
                        ),
                        if (connectedName != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            connectedName,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isConnected)
                    TextButton(
                      onPressed: _isConnecting
                          ? null
                          : () => _disconnect(),
                      child: Text(
                        'Disconnect',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Scan button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isScanning
                    ? null
                    : () => _scanDevices(),
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.primaryOrange),
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching_rounded),
                label: Text(
                  _isScanning ? 'Scanning...' : 'Scan Devices',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: const BorderSide(color: AppColors.primaryOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Discovered devices
            Text(
              'Available Devices',
              style: AppTextStyles.heading3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),

            devicesAsync.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bluetooth_disabled_rounded,
                          size: 48,
                          color: AppColors.textHint.withOpacity(0.4),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No devices found',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tap "Scan Devices" to search for Bluetooth printers',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: devices.map((device) {
                    final isCurrentlyConnected =
                        isConnected && connectedName == device.name;
                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentlyConnected
                            ? Border.all(
                                color: AppColors.successGreen,
                                width: 1.5)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isCurrentlyConnected
                                  ? AppColors.successGreen
                                      .withOpacity(0.1)
                                  : AppColors.infoBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.bluetooth_rounded,
                              color: isCurrentlyConnected
                                  ? AppColors.successGreen
                                  : AppColors.infoBlue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style:
                                      AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  device.macAdress,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          if (isCurrentlyConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Connected',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            TextButton(
                              onPressed: _isConnecting
                                  ? null
                                  : () => _connectToDevice(device),
                              child: Text(
                                'Connect',
                                style:
                                    AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Failed to scan: $e',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.errorRed),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Test print buttons
            if (isConnected) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _testPrint(),
                  icon: const Icon(Icons.receipt_rounded,
                      color: Colors.white),
                  label: Text(
                    'Test Print (ESC/POS)',
                    style: AppTextStyles.buttonText,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _rawTestPrint(),
                  icon: const Icon(Icons.bug_report_rounded),
                  label: Text(
                    'Raw Test (Diagnostic)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: const BorderSide(color: AppColors.primaryOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    ref.invalidate(availablePrintersProvider);
    // Wait for the provider to complete
    await ref.read(availablePrintersProvider.future);
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() => _isConnecting = true);
    try {
      final printerService = ref.read(printerServiceProvider);
      final success = await printerService.connect(device.macAdress);
      if (mounted) {
        if (success) {
          ref.read(printerConnectedProvider.notifier).state = true;
          ref.read(connectedPrinterNameProvider.notifier).state =
              device.name;
          await printerService.savePrinterName(device.name);

          // Also save to Terminal DB if a terminal is assigned
          final terminalId = ref.read(currentTerminalIdProvider);
          if (terminalId != null) {
            final db = ref.read(databaseProvider);
            await printerService.savePrinterToTerminal(
              db: db,
              terminalId: terminalId,
              address: device.macAdress,
              name: device.name,
            );
          }

          context.showSnackBar('Connected to ${device.name}');
        } else {
          context.showSnackBar('Failed to connect. Check Bluetooth permissions.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Connection error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isConnecting = true);
    try {
      final printerService = ref.read(printerServiceProvider);
      await printerService.disconnect();
      ref.read(printerConnectedProvider.notifier).state = false;
      ref.read(connectedPrinterNameProvider.notifier).state = null;

      // Also clear printer from Terminal DB
      final terminalId = ref.read(currentTerminalIdProvider);
      if (terminalId != null) {
        final db = ref.read(databaseProvider);
        await printerService.savePrinterToTerminal(
          db: db,
          terminalId: terminalId,
          address: null,
          name: null,
        );
      }

      if (mounted) {
        context.showSnackBar('Printer disconnected');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Disconnect error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _testPrint() async {
    final printerService = ref.read(printerServiceProvider);
    try {
      final bytes = await printerService.generateTestPrint();
      final success = await printerService.printReceipt(bytes);
      if (mounted) {
        if (success) {
          context.showSnackBar('Test print sent successfully');
        } else {
          context.showSnackBar('Test print failed — writeBytes returned false',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Print error: $e', isError: true);
      }
    }
  }

  Future<void> _rawTestPrint() async {
    final printerService = ref.read(printerServiceProvider);
    try {
      final success = await printerService.printRawTest();
      if (mounted) {
        if (success) {
          context.showSnackBar(
            'Raw bytes sent! Check printer for "HELLO" text.',
          );
        } else {
          context.showSnackBar(
            'Raw test failed — BT channel may not be working',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Raw test error: $e', isError: true);
      }
    }
  }

  /// Web-specific printer settings UI
  Widget _buildWebPrinterSettings(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Printer Settings', style: AppTextStyles.heading3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      color: AppColors.infoBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Browser Print Mode',
                    style: AppTextStyles.heading3.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Pada versi web, receipt akan dicetak menggunakan dialog print browser.\n\n'
                    'Gunakan Ctrl+P (Windows/Linux) atau Cmd+P (Mac) untuk mencetak receipt.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.infoBlue, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Untuk thermal printing, gunakan versi Android (APK)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
