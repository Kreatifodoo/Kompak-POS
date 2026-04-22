import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../modules/auth/auth_providers.dart';
import '../../core/utils/permissions.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  String _pin = '';
  bool _isLoading = false;
  bool _hasError = false;
  static const int _maxPinLength = 6;
  static const int _minPinLength = 4;

  // Rate limiting (ISS-024)
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get _isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  void _onKeyTap(String key) {
    if (_isLoading || _isLockedOut) return;

    setState(() {
      _hasError = false;
      if (key == 'backspace') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (key == 'clear') {
        _pin = '';
      } else if (key == 'enter') {
        if (_pin.length >= _minPinLength) {
          _authenticate();
        }
      } else if (_pin.length < _maxPinLength) {
        _pin += key;
        // Auto-submit at max length
        if (_pin.length == _maxPinLength) {
          _authenticate();
        }
      }
    });
  }

  Future<void> _authenticate() async {
    if (_isLockedOut) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      context.showSnackBar(
        'Terlalu banyak percobaan. Coba lagi dalam ${remaining}s',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authenticateProvider(_pin).future);
      if (!mounted) return;

      if (result != null) {
        _failedAttempts = 0;
        _lockoutUntil = null;
        // Navigate to default route. _isLoading stays true during transition
        // so the button shows a spinner — reset it here as a safety net in case
        // the widget is not replaced (e.g. same-route redirect edge case).
        if (mounted) setState(() => _isLoading = false);
        context.go(Permissions.defaultRoute(result.role));
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        }
        setState(() {
          _hasError = true;
          _pin = '';
          _isLoading = false;
        });
        if (_isLockedOut) {
          context.showSnackBar(
            'Terlalu banyak percobaan. Coba lagi dalam 30 detik',
            isError: true,
          );
        } else {
          context.showSnackBar('PIN salah. Silakan coba lagi.', isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _pin = '';
        _isLoading = false;
      });
      context.showSnackBar('Autentikasi gagal. Silakan coba lagi.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Header
            _buildHeader(),
            const SizedBox(height: AppSpacing.xxl),
            // PIN dots
            _buildPinDots(),
            const SizedBox(height: AppSpacing.lg),
            // Error text
            if (_hasError)
              Text(
                _isLockedOut ? 'Akun terkunci sementara' : 'PIN Salah',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
            const Spacer(flex: 1),
            // PIN pad
            _buildPinPad(),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Masukkan PIN',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Masukkan PIN Anda untuk melanjutkan',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textLight.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxPinLength, (index) {
        final isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? AppColors.primaryOrange
                : AppColors.textLight.withOpacity(0.2),
            border: isFilled
                ? null
                : Border.all(
                    color: _hasError
                        ? AppColors.errorRed.withOpacity(0.5)
                        : AppColors.textLight.withOpacity(0.3),
                    width: 1.5,
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildPinPad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['clear', '0', 'backspace'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          ...keys.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  return _buildKeyButton(key);
                }).toList(),
              ),
            );
          }),
          // Enter button row
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: (_pin.length >= _minPinLength && !_isLoading && !_isLockedOut)
                      ? () => _onKeyTap('enter')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    disabledBackgroundColor: AppColors.textLight.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Masuk',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String key) {
    Widget child;
    if (key == 'backspace') {
      child = const Icon(Icons.backspace_outlined, color: AppColors.textLight, size: 24);
    } else if (key == 'clear') {
      child = Text(
        'C',
        style: AppTextStyles.heading3.copyWith(color: AppColors.textLight),
      );
    } else {
      child = Text(
        key,
        style: AppTextStyles.heading2.copyWith(
          color: AppColors.textLight,
          fontSize: 28,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyTap(key),
        customBorder: const CircleBorder(),
        splashColor: AppColors.primaryOrange.withOpacity(0.3),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textLight.withOpacity(0.05),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
