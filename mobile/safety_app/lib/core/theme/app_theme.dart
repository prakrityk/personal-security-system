// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// App Theme Configuration
/// Provides light and dark theme data for the SOS app
class AppTheme {
  AppTheme._();

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.secondaryGreen,
      tertiary: AppColors.accentGreen1,
      error: AppColors.sosRed,
      surface: AppColors.lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightOnSurface,
      onError: Colors.white,
      surfaceContainerHighest: AppColors.lightDivider,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.lightBackground,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightOnSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.h4.copyWith(
        color: AppColors.lightOnSurface,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.button,
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: AppTextStyles.button,
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.button,
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.sosRed),
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.lightHint,
      ),
      hintStyle: AppTextStyles.hint.copyWith(color: AppColors.lightHint),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
    ),

    // Icon
    iconTheme: const IconThemeData(color: AppColors.primaryGreen, size: 24),

    // Text Theme
    textTheme: TextTheme(
      displayLarge: AppTextStyles.h1.copyWith(
        color: AppColors.lightOnBackground,
      ),
      displayMedium: AppTextStyles.h2.copyWith(
        color: AppColors.lightOnBackground,
      ),
      displaySmall: AppTextStyles.h3.copyWith(
        color: AppColors.lightOnBackground,
      ),
      headlineMedium: AppTextStyles.h4.copyWith(
        color: AppColors.lightOnBackground,
      ),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.lightOnSurface,
      ),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.lightOnSurface,
      ),
      bodySmall: AppTextStyles.bodySmall.copyWith(
        color: AppColors.lightOnSurface,
      ),
      labelLarge: AppTextStyles.labelLarge.copyWith(
        color: AppColors.lightOnSurface,
      ),
      labelMedium: AppTextStyles.labelMedium.copyWith(
        color: AppColors.lightOnSurface,
      ),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.lightHint),
    ),
  );

  // Dark Theme - Enhanced contrast
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkAccentGreen1,
      secondary: AppColors.secondaryGreen,
      tertiary: AppColors.darkAccentGreen2,
      error: AppColors.sosRed,
      surface: AppColors.darkSurface,
      onPrimary: AppColors.darkBackground,
      onSecondary: Colors.white,
      onSurface: AppColors.darkOnSurface,
      onError: Colors.white,
      surfaceContainerHighest: AppColors.darkDivider,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.darkBackground,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkOnSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.h4.copyWith(color: AppColors.darkOnSurface),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkAccentGreen1,
        foregroundColor: AppColors.darkBackground,
        elevation: 3,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.button.copyWith(
          color: AppColors.darkBackground,
        ),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkAccentGreen1,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: AppTextStyles.button,
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkAccentGreen1,
        side: const BorderSide(color: AppColors.darkAccentGreen1, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.button,
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.darkAccentGreen1,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.sosRed),
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.darkHint),
      hintStyle: AppTextStyles.hint.copyWith(color: AppColors.darkHint),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),

    // Icon - Enhanced visibility
    iconTheme: const IconThemeData(color: AppColors.darkIconActive, size: 24),

    // Text Theme - Enhanced readability
    textTheme: TextTheme(
      displayLarge: AppTextStyles.h1.copyWith(
        color: AppColors.darkOnBackground,
      ),
      displayMedium: AppTextStyles.h2.copyWith(
        color: AppColors.darkOnBackground,
      ),
      displaySmall: AppTextStyles.h3.copyWith(
        color: AppColors.darkOnBackground,
      ),
      headlineMedium: AppTextStyles.h4.copyWith(
        color: AppColors.darkOnBackground,
      ),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.darkOnSurface,
      ),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.darkOnSurface,
      ),
      bodySmall: AppTextStyles.bodySmall.copyWith(
        color: AppColors.darkOnSurface,
      ),
      labelLarge: AppTextStyles.labelLarge.copyWith(
        color: AppColors.darkOnSurface,
      ),
      labelMedium: AppTextStyles.labelMedium.copyWith(
        color: AppColors.darkOnSurface,
      ),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.darkHint),
    ),
  );
}
