import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — Teal/Cyan matching Kompak Apps branding
  static const Color primary = Color(0xFF0F80A6);
  static const Color primaryLight = Color(0xFF3DA5C7);
  static const Color primaryDark = Color(0xFF0A6080);

  // Legacy aliases (so existing 30+ files auto-inherit new colors)
  static const Color primaryOrange = primary;
  static const Color primaryOrangeLight = primaryLight;
  static const Color primaryOrangeDark = primaryDark;

  // Background
  static const Color scaffoldWhite = Color(0xFFFAFAFA);
  static const Color darkBackground = Color(0xFF000608);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textHint = Color(0xFF9CA3AF);

  // Status
  static const Color discountRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Surface
  static const Color surfaceGrey = Color(0xFFF3F4F6);
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color dividerGrey = Color(0xFFD1D5DB);

  // Category chip
  static const Color chipSelected = primary;
  static const Color chipUnselected = Color(0xFFF3F4F6);
}
