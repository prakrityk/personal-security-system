import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Text Styles
/// Defines typography using Roboto font family
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Roboto';

  // Headings - Bold/Black weights
  static TextStyle h1 = GoogleFonts.roboto(
    fontSize: 32,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: -0.5,
  );
    static TextStyle heading = GoogleFonts.roboto(
    fontSize: 32,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: -0.5,
  );

  static TextStyle h2 = GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: -0.5,
  );

  static TextStyle h3 = GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: 0,
  );

  static TextStyle h4 = GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: 0.15,
  );

  // SOS Emphasis - Black weight for critical actions
  static TextStyle sosEmphasis = GoogleFonts.roboto(
    fontSize: 18,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: 1.2,
  );

  // Labels & Buttons - Medium weight
  static TextStyle labelLarge = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
  );

  static TextStyle labelMedium = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
  );

  // Body Text - Regular weight
  static TextStyle bodyLarge = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.5,
  );

  static TextStyle bodyMedium = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
  );

  static TextStyle body = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
  );

  static TextStyle bodySmall = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
  );

  // Subtext & Hints - Thin/Light weights
  static TextStyle subtitle = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w300, // Light
    letterSpacing: 0.15,
  );

  static TextStyle caption = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w300, // Light
    letterSpacing: 0.4,
  );

  static TextStyle hint = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w100, // Thin
    letterSpacing: 0.4,
    fontStyle: FontStyle.italic,
  );

  // Button Text
  static TextStyle button = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 1.25,
  );

  static TextStyle buttonLarge = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 1.25,
  );
}
