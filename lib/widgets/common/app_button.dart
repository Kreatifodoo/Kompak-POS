import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double height;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.height = 52,
    this.padding,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.height = 52,
    this.padding,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.height = 52,
    this.padding,
  }) : variant = AppButtonVariant.secondary;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == AppButtonVariant.primary;
    final isDisabled = onPressed == null || isLoading;

    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor:
                isDisabled ? AppColors.borderGrey : AppColors.primaryOrange,
            foregroundColor: AppColors.textLight,
            elevation: 0,
            minimumSize: Size(isExpanded ? double.infinity : 0, height),
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor:
                isDisabled ? AppColors.textHint : AppColors.primaryOrange,
            side: BorderSide(
              color:
                  isDisabled ? AppColors.borderGrey : AppColors.primaryOrange,
              width: 1.5,
            ),
            elevation: 0,
            minimumSize: Size(isExpanded ? double.infinity : 0, height),
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );

    final textStyle = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: isPrimary
          ? AppColors.textLight
          : (isDisabled ? AppColors.textHint : AppColors.primaryOrange),
    );

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? AppColors.textLight : AppColors.primaryOrange,
              ),
            ),
          )
        : Row(
            mainAxisSize:
                isExpanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: textStyle),
            ],
          );

    if (isPrimary) {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: child,
    );
  }
}
