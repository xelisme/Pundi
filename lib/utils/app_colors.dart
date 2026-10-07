import 'package:flutter/material.dart';

/// Pundi Design System
/// Bold green primary, vibrant semantic colors, one cool neutral ramp.
///
/// Sumber kebenaran untuk warna. Berkas lain tidak boleh menulis hex sendiri.
class AppColors {
  AppColors._();

  // --- Brand ---
  static const Color green = Color(0xFF58CC02);
  static const Color greenShadow = Color(0xFF61B800); // tepi 3D tombol
  static const Color blue = Color(0xFF1CB0F6);

  // --- Uang ---
  static const Color income = Color(0xFF58CC02);
  static const Color expense = Color(0xFFFF4B4B);

  // --- Hierarki teks ---
  // #777777 → #6B6B6B: yang lama 4.48:1 di atas putih, nyaris di bawah
  // lantai 4.5:1, dan ia memikul 52 call site teks sekunder.
  static const Color textPrimary = Color(0xFF100F3E);
  static const Color textSecondary = Color(0xFF4B4B4B);
  static const Color textTertiary = Color(0xFF6B6B6B);

  // Label navigasi nonaktif. #AFAFAF = 2.3:1, tak terbaca di ukuran label.
  static const Color grayNav = Color(0xFF767676);

  // --- Baris dimmed (kategori arsip / nonaktif) ---
  // Sebelumnya Colors.grey.shade600/500/400. shade500 berada di 2.85:1 dan
  // dipakai untuk nominal rupiah.
  static const Color dimmedTitle = Color(0xFF5F5F5F);
  static const Color dimmedSecondary = Color(0xFF767676);
  static const Color dimmedIndicator = Color(0xFFB0B0B0);

  // --- Garis ---
  static const Color border = Color(0xFFE5E5E5);
  static const Color divider = Color(0xFFF0F0F0);

  // --- Permukaan ---
  // Halaman. #FFFFFF juga: hanya beda 1/255 dari surfaceWhite, jadi tidak
  // ada kartu yang bisa memisahkan diri kecuali lewat border.
  static const Color background = Color(0xFFF3F6F3);
  // Kartu, dan teks/ikon putih di atas hijau. #FEFEFE → putih betulan.
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // --- Status ---
  static const Color error = Color(0xFFFF4B4B);
  static const Color warning = Color(0xFFFF9600);
  static const Color success = Color(0xFFFFC800);

  // --- Kedalaman ---
  static const Color cardShadow = Color(0x14000000); // hitam @ 8%
  static const Color errorShadow = Color(0xFFCC0000);
  static const Color warningShadow = Color(0xFFCC7700);
  static const Color successShadow = Color(0xFFCCA000);

  // --- Tint ---
  static Color accentTint = green.withValues(alpha: 0.06);

  // --- Alias lama yang masih terpanggil di call site ---
  static const Color accent = green;
  static const Color baseBeige = background;
  static const Color baseBrown = textPrimary;
  static const Color textMedium = textSecondary;
}
