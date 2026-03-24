import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';

class PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final double buttonSize;
  final double spacing;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    this.buttonSize = 72,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        SizedBox(height: spacing),
        _buildRow(['4', '5', '6']),
        SizedBox(height: spacing),
        _buildRow(['7', '8', '9']),
        SizedBox(height: spacing),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _DigitButton(
            label: digit,
            onTap: () => onDigit(digit),
            size: buttonSize,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _ActionButton(
            icon: Icons.clear_all_rounded,
            onTap: onClear,
            size: buttonSize,
            color: AppColors.warningAmber,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _DigitButton(
            label: '0',
            onTap: () => onDigit('0'),
            size: buttonSize,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _ActionButton(
            icon: Icons.backspace_outlined,
            onTap: onBackspace,
            size: buttonSize,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double size;

  const _DigitButton({
    required this.label,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceGrey,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.primaryOrange.withOpacity(0.2),
        highlightColor: AppColors.primaryOrange.withOpacity(0.1),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: color.withOpacity(0.2),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(
              icon,
              size: size * 0.35,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
