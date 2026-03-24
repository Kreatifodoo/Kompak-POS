import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';

class QuantitySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double buttonSize;

  const QuantitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    this.buttonSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.remove,
          onTap: canDecrement ? () => onChanged(value - 1) : null,
          size: buttonSize,
          isEnabled: canDecrement,
        ),
        SizedBox(
          width: buttonSize + AppSpacing.sm,
          child: Center(
            child: Text(
              value.toString(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        _CircleButton(
          icon: Icons.add,
          onTap: canIncrement ? () => onChanged(value + 1) : null,
          size: buttonSize,
          isEnabled: canIncrement,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool isEnabled;

  const _CircleButton({
    required this.icon,
    this.onTap,
    required this.size,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isEnabled
          ? AppColors.primaryOrange.withOpacity(0.1)
          : AppColors.surfaceGrey,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(
              icon,
              size: size * 0.5,
              color: isEnabled
                  ? AppColors.primaryOrange
                  : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}
