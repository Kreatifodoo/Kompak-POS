import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/utils/formatters.dart';

enum PriceTagSize { small, medium, large }

class PriceTag extends StatelessWidget {
  final double price;
  final PriceTagSize size;
  final Color? color;
  final bool showCurrencyPrefix;
  final TextDecoration? decoration;

  const PriceTag({
    super.key,
    required this.price,
    this.size = PriceTagSize.medium,
    this.color,
    this.showCurrencyPrefix = true,
    this.decoration,
  });

  double get _prefixFontSize {
    switch (size) {
      case PriceTagSize.small:
        return 10;
      case PriceTagSize.medium:
        return 12;
      case PriceTagSize.large:
        return 14;
    }
  }

  double get _priceFontSize {
    switch (size) {
      case PriceTagSize.small:
        return 14;
      case PriceTagSize.medium:
        return 16;
      case PriceTagSize.large:
        return 24;
    }
  }

  FontWeight get _fontWeight {
    switch (size) {
      case PriceTagSize.small:
        return FontWeight.w600;
      case PriceTagSize.medium:
        return FontWeight.w700;
      case PriceTagSize.large:
        return FontWeight.w700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.textPrimary;
    final formattedPrice = Formatters.currencyCompact(price);

    return Text.rich(
      TextSpan(
        children: [
          if (showCurrencyPrefix)
            TextSpan(
              text: 'Rp ',
              style: GoogleFonts.poppins(
                fontSize: _prefixFontSize,
                fontWeight: _fontWeight,
                color: textColor,
                decoration: decoration,
              ),
            ),
          TextSpan(
            text: formattedPrice,
            style: GoogleFonts.poppins(
              fontSize: _priceFontSize,
              fontWeight: _fontWeight,
              color: textColor,
              decoration: decoration,
            ),
          ),
        ],
      ),
    );
  }
}
