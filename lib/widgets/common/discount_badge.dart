import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';

class DiscountBadge extends StatelessWidget {
  final double percentage;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const DiscountBadge({
    super.key,
    required this.percentage,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.discountRed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '-${percentage.toStringAsFixed(percentage.truncateToDouble() == percentage ? 0 : 1)}%',
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
