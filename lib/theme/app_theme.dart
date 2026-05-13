import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary palette — medical blue
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF003C8F);
  static const Color accent = Color(0xFF00ACC1);

  // Background / surface — clean white
  static const Color background = Color(0xFFF8FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4FF);
  static const Color cardBorder = Color(0xFFE8EDF5);

  // Text
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF5A6380);
  static const Color textDisabled = Color(0xFFB0BAD0);

  // Skin parameter colors — by score range
  static const Color scoreExcellent = Color(0xFF2E7D32); // 0–2
  static const Color scoreGood = Color(0xFF558B2F);      // 2–4
  static const Color scoreMedium = Color(0xFFF9A825);    // 4–6
  static const Color scorePoor = Color(0xFFE65100);      // 6–8
  static const Color scoreCritical = Color(0xFFC62828);  // 8–9.9

  // Device status
  static const Color connected = Color(0xFF2E7D32);
  static const Color disconnected = Color(0xFFB71C1C);
  static const Color scanning = Color(0xFFF57F17);

  // Parameter brand colors (for radar chart)
  static const List<Color> paramColors = [
    Color(0xFF1565C0), // Umidità
    Color(0xFF00897B), // Olio
    Color(0xFF6A1B9A), // Texture
    Color(0xFF558B2F), // Fibra collagene
    Color(0xFF37474F), // Rughe
    Color(0xFFAD1457), // Pigmentazione
    Color(0xFFE65100), // Sensibilità
    Color(0xFF00695C), // Pori
  ];

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
      displayMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
      headlineMedium: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
      headlineSmall: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
      bodyMedium: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
      labelLarge: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary,
          letterSpacing: 0.5),
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: textDisabled),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Colore in base allo score (0–9.9)
  static Color scoreColor(double score) {
    if (score < 2.0) return scoreExcellent;
    if (score < 4.0) return scoreGood;
    if (score < 6.0) return scoreMedium;
    if (score < 8.0) return scorePoor;
    return scoreCritical;
  }

  /// Label testuale del range
  static String scoreLabel(double score) {
    if (score < 2.0) return 'Eccellente';
    if (score < 4.0) return 'Buono';
    if (score < 6.0) return 'Nella norma';
    if (score < 8.0) return 'Attenzione';
    return 'Critico';
  }
}
