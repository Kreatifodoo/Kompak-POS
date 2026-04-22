import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../modules/lan_sync/lan_sync_providers.dart';
import '../../modules/pos_session/pos_session_providers.dart';

class LanSyncScreen extends ConsumerStatefulWidget {
  const LanSyncScreen({super.key});

  @override
  ConsumerState<LanSyncScreen> createState() => _LanSyncScreenState();
}

class _LanSyncScreenState extends ConsumerState<LanSyncScreen> {
  final _ipController = TextEditingController();
  String? _selectedSessionId;
  bool _isSending = false;
  String _sendStatus = '';

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _toggleServer() async {
    final service = ref.read(lanSyncServiceProvider);
    final running = ref.read(lanServerRunningProvider);

    try {
      if (running) {
        await service.stopServer();
        ref.read(lanServerRunningProvider.notifier).state = false;
        if (mounted) context.showSnackBar('Server dihentikan');
      } else {
        await service.startServer();
        ref.read(lanServerRunningProvider.notifier).state = true;
        if (mounted) context.showSnackBar('Server berjalan di port 8080');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _sendSession() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      context.showSnackBar('Masukkan IP tujuan', isError: true);
      return;
    }
    if (_selectedSessionId == null) {
      context.showSnackBar('Pilih sesi yang ingin dikirim', isError: true);
      return;
    }

    setState(() {
      _isSending = true;
      _sendStatus = 'Mengirim...';
    });

    try {
      final service = ref.read(lanSyncServiceProvider);

      // Ping first
      setState(() => _sendStatus = 'Mengecek koneksi...');
      final reachable = await service.pingDevice(ip);
      if (!reachable) {
        setState(() => _sendStatus = 'Device tidak ditemukan');
        if (mounted) {
          context.showSnackBar('Tidak dapat terhubung ke $ip', isError: true);
        }
        return;
      }

      setState(() => _sendStatus = 'Mengirim data sesi...');
      await service.sendSession(ip, _selectedSessionId!);
      setState(() => _sendStatus = 'Berhasil dikirim!');
      if (mounted) context.showSnackBar('Sesi berhasil dikirim ke $ip');
    } catch (e) {
      setState(() => _sendStatus = 'Gagal: $e');
      if (mounted) context.showSnackBar('Gagal mengirim: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(lanServerRunningProvider);
    final ipAsync = ref.watch(lanServerIpProvider);
    final sessionsAsync = ref.watch(sessionHistoryProvider);

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
        title: Text('LAN Sync', style: AppTextStyles.heading3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ─── SERVER SECTION ───────────────────────────────
          _buildSectionHeader('Server Mode', Icons.dns_rounded),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Status row
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isRunning
                              ? AppColors.successGreen
                              : AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        isRunning ? 'Server Aktif' : 'Server Mati',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isRunning
                              ? AppColors.successGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // IP display
                  ipAsync.when(
                    data: (ip) => ip != null
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'IP: $ip:8080',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Text('Tidak terhubung ke jaringan',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.errorRed)),
                    loading: () => const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => Text('Gagal mendapatkan IP',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.errorRed)),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Toggle button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _toggleServer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning
                            ? AppColors.errorRed
                            : AppColors.successGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(
                        isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        isRunning ? 'Stop Server' : 'Start Server',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ─── CLIENT SECTION ───────────────────────────────
          _buildSectionHeader('Kirim ke Device Lain', Icons.send_rounded),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target IP
                  Text('IP Tujuan',
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '192.168.1.100',
                      prefixIcon: const Icon(Icons.wifi_rounded,
                          color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Session picker
                  Text('Pilih Sesi',
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  sessionsAsync.when(
                    data: (sessions) {
                      final closed = sessions
                          .where((s) => s.status == 'closed')
                          .toList();
                      if (closed.isEmpty) {
                        return Text('Belum ada sesi yang ditutup',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary));
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedSessionId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        hint: const Text('Pilih sesi...'),
                        items: closed
                            .take(20)
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    '${Formatters.dateTime(s.openedAt)} — ${s.status}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedSessionId = val),
                      );
                    },
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (e, _) => Text('Error: $e',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.errorRed)),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        disabledBackgroundColor: AppColors.borderGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white),
                      label: Text(
                        'Kirim Session',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Status text
                  if (_sendStatus.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _sendStatus,
                      style: AppTextStyles.caption.copyWith(
                        color: _sendStatus.contains('Berhasil')
                            ? AppColors.successGreen
                            : _sendStatus.contains('Gagal')
                                ? AppColors.errorRed
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryOrange),
        const SizedBox(width: AppSpacing.sm),
        Text(title,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
