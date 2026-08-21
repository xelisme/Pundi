import 'package:flutter/material.dart';

/// Pundi Duolingo-Inspired Design System
/// Bright, playful, gamified palette
/// Bold green primary, vibrant semantic colors
class AppColors {
  AppColors._();

  // Duolingo Primary Colors
  static const Color green = Color(0xFF58CC02); // Duolingo primary green
  static const Color greenHover = Color(0xFF4BB200); // Green hover state
  static const Color greenShadow = Color(0xFF61B800); // 3D button shadow
  
  // Duolingo Semantic Colors
  static const Color blue = Color(0xFF1CB0F6); // Info/link blue
  static const Color darkBlue = Color(0xFF100F3E); // Dark text/headers
  static const Color red = Color(0xFFFF4B4B); // Error/destructive
  static const Color orange = Color(0xFFFF9600); // Warning
  static const Color golden = Color(0xFFFFC800); // Success/achievement
  
  // Neutral Grays (Duolingo style)
  static const Color grayText = Color(0xFF4B4B4B); // Primary body text
  static const Color grayLight = Color(0xFF777777); // Secondary text
  static const Color grayNav = Color(0xFFAFAFAF); // Nav inactive
  static const Color borderColor = Color(0xFFE5E5E5); // Borders/dividers
  
  // Backgrounds
  static const Color background = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceWhite = Color(0xFFFEFEFE); // Card surfaces
  static const Color footerGreen = Color(0xFF4EC604); // Footer accent
  
  // Gradient Colors (for hero sections)
  static const Color gradientGreenStart = Color(0xFF58CC02);
  static const Color gradientGreenEnd = Color(0xFFFFFFFF);
  
  // Income/Expense (adapted to Duolingo palette)
  static const Color income = Color(0xFF58CC02); // Green for income
  static const Color expense = Color(0xFFFF4B4B); // Red for expense
  
  // Text Hierarchy (Duolingo style)
  static const Color textPrimary = darkBlue; // Deep blue-black
  static const Color textSecondary = grayText; // Medium gray
  static const Color textTertiary = grayLight; // Light gray
  
  // Borders and Dividers
  static const Color border = borderColor;
  static const Color divider = Color(0xFFF0F0F0); // Very light divider
  
  // State Colors
  static const Color success = golden; // Achievement gold
  static const Color error = red; // Error red
  static const Color warning = orange; // Warning orange
  
  // Tints (light backgrounds)
  static Color incomeTint = green.withValues(alpha: 0.1);
  static Color expenseTint = red.withValues(alpha: 0.1);
  static Color blueTint = blue.withValues(alpha: 0.1);
  static Color goldenTint = golden.withValues(alpha: 0.1);
  
  // Shadow Colors (for 3D effect)
  static Color shadowColor = Colors.black.withValues(alpha: 0.12);
  static Color shadowLight = Colors.black.withValues(alpha: 0.06);
  
  // Legacy compatibility aliases (for gradual migration)
  static const Color primary = green; // Main CTA color
  static const Color accent = green; // Accent color
  static const Color baseBeige = background; // Map old beige to white
  static const Color baseBrown = darkBlue; // Map old brown to dark blue
  static const Color textMedium = textSecondary;
  static const Color textLight = textTertiary;
  static Color primaryLight = green.withValues(alpha: 0.1);
  static Color accentTint = green.withValues(alpha: 0.06);
  
  // Category colors (bright, not muted)
  static const Color categoryTint1 = Color(0xFF1CB0F6); // Bright blue
  static const Color categoryTint2 = Color(0xFFFF9600); // Bright orange
  static const Color categoryTint3 = Color(0xFFFFC800); // Bright golden
}
