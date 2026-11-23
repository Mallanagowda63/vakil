import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Legally Talk Partner: bench green and brass.
  static const Color primary = Color(0xFF0E4D45);
  static const Color primaryDark = Color(0xFF0E2C28);
  static const Color success = Color(0xFF1F8A5B);
  static const Color background = Color(0xFFF5F7F6);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDCE3E1);
  static const Color textPrimary = Color(0xFF14211F);
  static const Color textSecondary = Color(0xFF5D6B68);
  static const Color danger = Color(0xFFB9382B);
  static const Color infoBg = Color(0xFFDCEBE7);
  static const Color gold = Color(0xFFB8820F);
  static const Color goldSoft = Color(0xFFF7ECD3);

  // Dark theme used by the voice call screens.
  static const Color callBackground = Color(0xFF0B1730);
  static const Color callSurface = Color(0xFF15224A);
  static const Color callBorder = Color(0xFF2A3B6B);
  static const Color callTextSecondary = Color(0xFF9AA6C8);
}

/// The design's colour tokens for the current brightness (light / dark).
/// New screens use these so the dark mode toggle on Home works everywhere.
class LT {
  const LT._({required this.bg, required this.surface, required this.surface2, required this.ink, required this.muted, required this.line,
    required this.brand, required this.brandInk, required this.brandSoft, required this.gold, required this.goldSoft,
    required this.good, required this.goodSoft, required this.bad, required this.badSoft, required this.nav, required this.navInk, required this.navOn});
  final Color bg, surface, surface2, ink, muted, line, brand, brandInk, brandSoft, gold, goldSoft, good, goodSoft, bad, badSoft, nav, navInk, navOn;

  static const light = LT._(
    bg: Color(0xFFF5F7F6), surface: Color(0xFFFFFFFF), surface2: Color(0xFFEDF2F0), ink: Color(0xFF14211F), muted: Color(0xFF5D6B68), line: Color(0xFFDCE3E1),
    brand: Color(0xFF0E4D45), brandInk: Color(0xFFFFFFFF), brandSoft: Color(0xFFDCEBE7), gold: Color(0xFFB8820F), goldSoft: Color(0xFFF7ECD3),
    good: Color(0xFF1F8A5B), goodSoft: Color(0xFFDDF1E6), bad: Color(0xFFB9382B), badSoft: Color(0xFFF8E1DE),
    nav: Color(0xFF0E2C28), navInk: Color(0xFF9DB8B2), navOn: Color(0xFFFFFFFF));
  static const dark = LT._(
    bg: Color(0xFF0D1413), surface: Color(0xFF15201E), surface2: Color(0xFF1B2826), ink: Color(0xFFE7EFED), muted: Color(0xFF93A4A0), line: Color(0xFF263532),
    brand: Color(0xFF5FC3B1), brandInk: Color(0xFF062420), brandSoft: Color(0xFF173A35), gold: Color(0xFFE5B24A), goldSoft: Color(0xFF3A2E14),
    good: Color(0xFF4CC38A), goodSoft: Color(0xFF173A2A), bad: Color(0xFFEF6A5B), badSoft: Color(0xFF3D1E1A),
    nav: Color(0xFF0A1715), navInk: Color(0xFF7E9692), navOn: Color(0xFFE7EFED));

  static LT of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9AA1AE), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: LT.dark.brand,
        surface: LT.dark.bg,
      ),
      scaffoldBackgroundColor: LT.dark.bg,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1413),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
    );
  }
}
