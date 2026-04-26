// lib/theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KakaWiseTheme {
  // ── Core palette ─────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF2D5A1B); // deep forest green
  static const Color primaryLight  = Color(0xFF4A8C2A);

  // Header background — distinctly darker/richer green than body
  static const Color headerBg      = Color(0xFF1E3D12);
  static const Color headerText    = Color(0xFFE8F5DE);
  static const Color headerSub     = Color(0xFF9DC87A);

  static const Color accent        = Color(0xFFD4A017); // warm cocoa gold
  static const Color surface       = Color(0xFFF4F1EC); // warm off-white body
  static const Color cardBg        = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1C1C1C);
  static const Color textSecondary = Color(0xFF6B6560);

  // Warm brown border — NOT blue
  static const Color border        = Color(0xFFD6CFC4);

  // Per-variety accent colours
  static const Color w10Color  = Color(0xFF1D9E75);
  static const Color uf18Color = Color(0xFF7F77DD);
  static const Color br25Color = Color(0xFFEF9F27);

  static ThemeData get theme {
    // Use Inter for all body text — uniform stroke weight (no thick-thin)
    final inter = GoogleFonts.interTextTheme().copyWith(
      bodyLarge:   GoogleFonts.inter(fontSize: 16, color: textPrimary,   height: 1.5),
      bodyMedium:  GoogleFonts.inter(fontSize: 14, color: textPrimary,   height: 1.5),
      bodySmall:   GoogleFonts.inter(fontSize: 12, color: textSecondary, height: 1.4),
      labelMedium: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      labelSmall:  GoogleFonts.inter(fontSize: 10, color: textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: inter,
      appBarTheme: AppBarTheme(
        backgroundColor: headerBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          fontSize: 26,
          fontWeight: FontWeight.w400,
          color: headerText,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: headerText),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 0.5),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}