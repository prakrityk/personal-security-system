import 'package:flutter/material.dart';

/// App Text Styles
/// Defines typography using Inter font family from local assets
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Inter';

  // Headings - Bold/Black weights
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: -0.5,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: -0.5,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: 0,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: 0.15,
  );

  // SOS Emphasis - Black weight for critical actions
  static const TextStyle sosEmphasis = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: 1.2,
  );

  // Labels & Buttons - Medium/SemiBold weight
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 0.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 0.5,
  );

  // Body Text - Regular weight
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
  );

  // Subtext & Hints - Light weights
  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w300, // Light
    letterSpacing: 0.15,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w300, // Light
    letterSpacing: 0.4,
  );

  static const TextStyle hint = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w300, // Light
    letterSpacing: 0.4,
    fontStyle: FontStyle.italic,
  );

  // Button Text
  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 1.25,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 1.25,
  );
}
