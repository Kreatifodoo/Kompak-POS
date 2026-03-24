import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/models/enums.dart';

/// Result returned by [showDiscountInputDialog] when the user confirms.
class DiscountResult {
  final DiscountType type;
  final double value;

  const DiscountResult({required this.type, required this.value});
}

/// Shows a dialog that lets the cashier choose between a percentage or fixed
/// discount and enter a value.
///
/// Returns a [DiscountResult] when confirmed, or `null` if dismissed.
///
/// ```dart
/// final result = await showDiscountInputDialog(context);
/// if (result != null) {
///   // apply result.type and result.value
/// }
/// ```
Future<DiscountResult?> showDiscountInputDialog(BuildContext context) {
  return showDialog<DiscountResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _DiscountInputDialog(),
  );
}

class _DiscountInputDialog extends StatefulWidget {
  const _DiscountInputDialog();

  @override
  State<_DiscountInputDialog> createState() => _DiscountInputDialogState();
}

class _DiscountInputDialogState extends State<_DiscountInputDialog> {
  DiscountType _selectedType = DiscountType.percentage;
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a value';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive number';
    }
    if (_selectedType == DiscountType.percentage && parsed > 100) {
      return 'Percentage cannot exceed 100%';
    }
    return null;
  }

  void _onConfirm() {
    if (!_formKey.currentState!.validate()) return;

    final value = double.parse(_controller.text.trim());
    Navigator.of(context).pop(
      DiscountResult(type: _selectedType, value: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Apply Discount',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Discount type toggle
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Percentage',
                      icon: Icons.percent_rounded,
                      isSelected: _selectedType == DiscountType.percentage,
                      onTap: () => setState(
                          () => _selectedType = DiscountType.percentage),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TypeButton(
                      label: 'Fixed',
                      icon: Icons.attach_money_rounded,
                      isSelected: _selectedType == DiscountType.fixed,
                      onTap: () =>
                          setState(() => _selectedType = DiscountType.fixed),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Value input
              TextFormField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                autofocus: true,
                validator: _validate,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: _selectedType == DiscountType.percentage
                      ? 'e.g. 10'
                      : 'e.g. 5000',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textHint,
                  ),
                  suffixText:
                      _selectedType == DiscountType.percentage ? '%' : 'Rp',
                  suffixStyle: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceGrey,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryOrange,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.errorRed,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.errorRed,
                      width: 1.5,
                    ),
                  ),
                  errorStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.errorRed,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderGrey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? const Color.fromARGB(25, 255, 107, 53)
          : AppColors.surfaceGrey,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryOrange
                  : AppColors.borderGrey,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primaryOrange
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
