import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/pin_hash.dart';
import '../../modules/core_providers.dart';
import '../../widgets/common/pin_pad.dart';

/// Bottom sheet dialog yang meminta user mengetik PIN untuk masuk ke
/// halaman absensi multi-user. PIN diverifikasi terhadap seluruh user
/// aktif yang punya akses ke menu absensi (`canAccessAttendance`).
///
/// Returns [User] terverifikasi melalui [Navigator.pop] saat PIN cocok.
class AttendancePinDialog extends ConsumerStatefulWidget {
  const AttendancePinDialog({super.key});

  @override
  ConsumerState<AttendancePinDialog> createState() =>
      _AttendancePinDialogState();

  /// Helper untuk menampilkan dialog dan mengembalikan user terverifikasi.
  static Future<User?> show(BuildContext context) {
    return showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AttendancePinDialog(),
    );
  }
}

class _AttendancePinDialogState extends ConsumerState<AttendancePinDialog> {
  static const int _maxPinLength = 6;

  String _pin = '';
  bool _verifying = false;
  String? _errorMessage;

  void _onDigit(String d) {
    if (_verifying) return;
    if (_pin.length >= _maxPinLength) return;
    setState(() {
      _pin += d;
      _errorMessage = null;
    });
    if (_pin.length >= 4) {
      _tryVerify();
    }
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _onClear() {
    if (_verifying) return;
    setState(() {
      _pin = '';
      _errorMessage = null;
    });
  }

  Future<void> _tryVerify() async {
    setState(() => _verifying = true);

    try {
      final db = ref.read(databaseProvider);
      final hashed = PinHash.hash(_pin);

      // Lookup user by hashed PIN (existing UserDao helper).
      final user = await db.userDao.authenticateByPin(hashed);

      if (user == null) {
        setState(() {
          _errorMessage = 'PIN tidak ditemukan';
          _pin = '';
          _verifying = false;
        });
        return;
      }

      // Cek apakah user diizinkan mengakses absensi.
      final allowed = db.userDao.canAccessAttendance(user);
      if (!allowed) {
        setState(() {
          _errorMessage = 'User ini tidak punya akses absensi';
          _pin = '';
          _verifying = false;
        });
        return;
      }

      if (mounted) {
        Navigator.of(context).pop(user);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal verifikasi: $e';
        _pin = '';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fingerprint_rounded,
                        color: AppColors.primaryOrange, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Absensi Karyawan',
                            style: AppTextStyles.heading3),
                        Text('Masukkan PIN untuk memulai',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // PIN dots indicator
              _buildPinDots(),
              const SizedBox(height: AppSpacing.sm),

              // Error message
              SizedBox(
                height: 22,
                child: _errorMessage == null
                    ? const SizedBox.shrink()
                    : Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.errorRed),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),

              // PIN pad — same component as POS price input
              PinPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onClear: _onClear,
                buttonSize: 64,
                spacing: 14,
              ),

              const SizedBox(height: AppSpacing.md),
              if (_verifying)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Memverifikasi...',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxPinLength, (i) {
        final filled = i < _pin.length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: filled ? 16 : 12,
            height: filled ? 16 : 12,
            decoration: BoxDecoration(
              color: filled
                  ? AppColors.primaryOrange
                  : AppColors.borderGrey.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: filled
                    ? AppColors.primaryOrange
                    : AppColors.borderGrey,
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }
}

