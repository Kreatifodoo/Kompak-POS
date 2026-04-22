import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../modules/core_providers.dart';

class TelegramSettingsScreen extends ConsumerStatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  ConsumerState<TelegramSettingsScreen> createState() =>
      _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState
    extends ConsumerState<TelegramSettingsScreen> {
  final _tokenController = TextEditingController();
  final _chatIdController = TextEditingController();
  final _openaiKeyController = TextEditingController();
  bool _enabled = false;
  bool _chatbotEnabled = false;
  bool _isTesting = false;
  bool _isTestingChatbot = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    _tokenController.text = prefs.getString('telegram_bot_token') ?? '';
    _chatIdController.text = prefs.getString('telegram_chat_id') ?? '';
    _enabled = prefs.getBool('telegram_enabled') ?? false;
    _chatbotEnabled = prefs.getBool('telegram_chatbot_enabled') ?? false;
    _openaiKeyController.text = prefs.getString('openai_api_key') ?? '';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _chatIdController.dispose();
    _openaiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('telegram_bot_token', _tokenController.text.trim());
      await prefs.setString('telegram_chat_id', _chatIdController.text.trim());
      await prefs.setBool('telegram_enabled', _enabled);
      await prefs.setBool('telegram_chatbot_enabled', _chatbotEnabled);
      await prefs.setString('openai_api_key', _openaiKeyController.text.trim());

      // Restart chatbot polling with fresh config
      final chatbot = ref.read(telegramChatbotServiceProvider);
      chatbot.stopPolling(); // Stop first to pick up new config
      if (_chatbotEnabled) {
        chatbot.startPolling();
      }

      if (mounted) context.showSnackBar('Pengaturan Telegram tersimpan');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testChatbot() async {
    // Save settings first so service reads latest values
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('telegram_bot_token', _tokenController.text.trim());
    await prefs.setString('telegram_chat_id', _chatIdController.text.trim());
    await prefs.setString('openai_api_key', _openaiKeyController.text.trim());

    setState(() => _isTestingChatbot = true);
    try {
      final chatbot = ref.read(telegramChatbotServiceProvider);
      final result = await chatbot.testChatbot();
      if (mounted) {
        final isSuccess = !result.contains('❌');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(isSuccess ? 'Test Berhasil' : 'Test Gagal',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(result, style: AppTextStyles.bodySmall),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isTestingChatbot = false);
    }
  }

  Future<void> _testConnection() async {
    // Save first so TelegramService reads latest values
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('telegram_bot_token', _tokenController.text.trim());
    await prefs.setString('telegram_chat_id', _chatIdController.text.trim());

    setState(() => _isTesting = true);
    try {
      final telegram = ref.read(telegramServiceProvider);
      final ok = await telegram.testConnection();
      if (mounted) {
        if (ok) {
          context.showSnackBar('Koneksi berhasil! Cek Telegram Anda.');
        } else {
          context.showSnackBar('Koneksi gagal. Periksa token dan chat ID.',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Telegram', style: AppTextStyles.heading3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Info card
          Card(
            elevation: 0,
            color: AppColors.infoBlue.withOpacity(0.08),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.infoBlue, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Laporan tutup kasir akan dikirim otomatis ke Telegram saat sesi ditutup.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.infoBlue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Enable toggle
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: Text('Aktifkan Telegram',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _enabled ? 'Laporan akan dikirim saat tutup kasir' : 'Nonaktif',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              value: _enabled,
              activeColor: AppColors.primaryOrange,
              onChanged: (val) => setState(() => _enabled = val),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Bot token
          Text('Bot Token',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Masukkan bot token dari @BotFather',
              prefixIcon:
                  const Icon(Icons.key_rounded, color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Chat ID
          Text('Chat ID',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _chatIdController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: 'Chat ID atau Group ID',
              prefixIcon: const Icon(Icons.chat_rounded,
                  color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.infoBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: AppColors.infoBlue),
                    label: Text(
                      'Test Koneksi',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.infoBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Text(
                            'Simpan',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),

          // ─── AI CHATBOT SECTION ───────────────────────────
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded,
                  size: 20, color: Colors.deepPurple),
              const SizedBox(width: AppSpacing.sm),
              Text('AI Chatbot',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Chatbot info
          Card(
            elevation: 0,
            color: Colors.deepPurple.withValues(alpha: 0.06),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Tanya data POS lewat Telegram! Contoh:\n'
                '"Berapa penjualan hari ini?"\n'
                '"Top produk minggu ini?"\n'
                '"Cek stok"',
                style: AppTextStyles.caption
                    .copyWith(color: Colors.deepPurple),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Chatbot toggle
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: Text('Aktifkan AI Chatbot',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _chatbotEnabled
                    ? 'Bot aktif & layar tetap menyala agar selalu merespon'
                    : 'Nonaktif',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              value: _chatbotEnabled,
              activeColor: Colors.deepPurple,
              onChanged: (val) => setState(() => _chatbotEnabled = val),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // OpenAI API Key
          Text('OpenAI API Key',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _openaiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'API key dari platform.openai.com',
              prefixIcon: const Icon(Icons.smart_toy_rounded,
                  color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Dapatkan di platform.openai.com → API Keys',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Test AI Chatbot button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isTestingChatbot ? null : _testChatbot,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isTestingChatbot
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.deepPurple),
                      ),
                    )
                  : const Icon(Icons.science_rounded,
                      color: Colors.deepPurple),
              label: Text(
                _isTestingChatbot
                    ? 'Testing...'
                    : 'Test AI Chatbot',
                style: AppTextStyles.bodySmall
                    .copyWith(color: Colors.deepPurple),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),

          // Help section
          Text('Cara Mendapatkan Bot Token & Chat ID',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          _buildHelpStep('1', 'Buka Telegram, cari @BotFather'),
          _buildHelpStep('2', 'Kirim /newbot dan ikuti instruksi'),
          _buildHelpStep('3', 'Salin token yang diberikan'),
          _buildHelpStep(
              '4', 'Untuk Chat ID, kirim pesan ke bot lalu buka: api.telegram.org/bot<TOKEN>/getUpdates'),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(number,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
