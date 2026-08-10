import 'package:flutter/material.dart';

/// BudgetAI Luxury Minimal Design System
/// Near-monochrome palette with warm sophistication
/// Refined restraint, expensive simplicity
class AppColors {
  AppColors._();

  // Base palette - warm neutrals
  static const Color baseBeige = Color(0xFFE8E4DD); // Primary background - warm, soft
  static const Color baseBrown = Color(0xFF2C2420); // Primary text - deep, rich
  static const Color surfaceWhite = Color(0xFFFDFBF7); // Cards and elevated surfaces
  
  // Accent - burgundy for key actions
  static const Color accent = Color(0xFF8B3A3A); // Refined burgundy for CTAs
  
  // Subtle tints for categories (desaturated from base)
  static const Color categoryTint1 = Color(0xFFD4C5B9); // Warm sand
  static const Color categoryTint2 = Color(0xFFC4B5A6); // Deeper sand
  static const Color categoryTint3 = Color(0xFFB8A594); // Rich taupe
  
  // Semantic colors - subtle, refined
  static const Color income = Color(0xFF6B7F6E); // Muted sage
  static const Color expense = Color(0xFF8B6B5F); // Muted terracotta
  
  // Text hierarchy
  static const Color textPrimary = baseBrown; // Deep brown
  static const Color textSecondary = Color(0xFF5A4E47); // Lighter brown
  static const Color textTertiary = Color(0xFF8A7F77); // Very light brown
  
  // Borders and dividers
  static const Color border = Color(0xFFD9D3CC); // Subtle warm gray
  static const Color divider = Color(0xFFEBE7E1); // Very subtle
  
  // State colors - restrained
  static const Color success = income;
  static const Color error = expense;
  static const Color warning = Color(0xFFB89968); // Muted gold
  
  // Backgrounds with subtle opacity
  static Color incomeTint = income.withValues(alpha: 0.08);
  static Color expenseTint = expense.withValues(alpha: 0.08);
  static Color accentTint = accent.withValues(alpha: 0.06);
  
  // Shadow color - warm, not gray
  static Color shadowColor = const Color(0xFF504028).withValues(alpha: 0.06);
  
  // Legacy compatibility aliases (for gradual migration)
  static const Color background = baseBeige;
  static const Color primary = accent;
  static const Color textMedium = textSecondary;
  static const Color textLight = textTertiary;
  static Color primaryLight = accent.withValues(alpha: 0.1);
  static Color incomeLight = income.withValues(alpha: 0.1);
  static Color expenseLight = expense.withValues(alpha: 0.1);
}
