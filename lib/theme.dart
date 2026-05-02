// lib/theme.dart
//
// Colour palette inspired by real cacao: deep pod reds, warm brown husk,
// cream bean interior, forest shadow. Replaces the previous green palette.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KakaWiseTheme {
  // ── Core cacao palette ───────────────────────────────────────────────────────
  // Deep, rich pod-exterior red — used as the primary action colour
  static const Color primary      = Color(0xFF7B2D00); // dark cacao red
  static const Color primaryLight = Color(0xFFA33D00); // lighter pod red

  // Header — very dark pod-brown, like the husk in shadow
  static const Color headerBg     = Color(0xFF3D1200); // almost black-brown
  static const Color headerText   = Color(0xFFF5E6D3); // cream bean colour
  static const Color headerSub    = Color(0xFFC49A6C); // dried-husk gold

  // Accent — ripe orange-yellow of a mature cacao pod
  static const Color accent       = Color(0xFFD4820A);

  // Body backgrounds
  static const Color surface      = Color(0xFFFAF5F0); // warm cream paper
  static const Color cardBg       = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary   = Color(0xFF1C1008); // almost black-brown
  static const Color textSecondary = Color(0xFF7A5C45); // warm mid-brown

  // Border — warm tan, matches parchment
  static const Color border       = Color(0xFFDDCCBA);

  // ── Per-variety accent colours ───────────────────────────────────────────────
  // Kept distinct but shifted to harmonise with the brown palette
  static const Color w10Color  = Color(0xFF1D7A60); // teal-green (leaf)
  static const Color uf18Color = Color(0xFF6B5BBF); // purple-indigo
  static const Color br25Color = Color(0xFFD4820A); // amber-gold (ripe pod)

  static ThemeData get theme {
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