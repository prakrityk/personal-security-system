// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// App Color Palette
/// Defines all colors used throughout the SOS app
class AppColors {
  AppColors._();

  // Primary & Supporting Colors
  static const Color primaryGreen = Color(0xFF2F5249);
  static const Color primary = Color(0xFF2F5249);
  static const Color secondaryGreen = Color(0xFF437057);
  static const Color accentGreen1 = Color(0xFF97B067);
  static const Color accentGreen2 = Color(0xFFE3DE61);

  // Critical Action Color
  static const Color sosRed = Color.fromARGB(255, 167, 67, 55);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnBackground = Color(0xFF1A1A1A);
  static const Color lightOnSurface = Color(0xFF2C2C2C);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightHint = Color(0xFF9E9E9E);

  // Dark Mode Colors - Enhanced contrast
  static const Color darkBackground = Color(0xFF121614);
  static const Color darkSurface = Color(0xFF1E2623);
  static const Color darkOnBackground = Color(0xFFF0F0F0);
  static const Color darkOnSurface = Color(0xFFE8E8E8);
  static const Color darkDivider = Color(0xFF3E4340);
  static const Color darkHint = Color(0xFF9E9E9E);

  // Accent colors for dark mode - Brighter for better visibility
  static const Color darkAccentGreen1 = Color(0xFFAACA7A);
  static const Color darkAccentGreen2 = Color(0xFFEBE875);

  // Enhanced icon colors for dark mode
  static const Color darkIconActive = Color(0xFFAACA7A);
  static const Color darkIconInactive = Color(0xFF7A8A75);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF42A5F5);

  // Overlay Colors
  static Color lightScrim = Colors.black.withOpacity(0.4);
  static Color darkScrim = Colors.black.withOpacity(0.6);
}
