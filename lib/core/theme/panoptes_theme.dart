import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Panoptes Tactical Crimson-Obsidian Design System
/// Zero AI-Slop: Pure #000000 AMOLED canvas, sharp 1px architectural borders,
/// Crimson-Burgundy (#E11D48 / #BE123C / #881337) accent hierarchy, 48dp+ touch targets.
class PanoptesColors {
  PanoptesColors._();

  // Obsidian Dark Surfaces
  static const Color obsidian = Color(0xFF000000);
  static const Color surfaceBase = Color(0xFF07070A);
  static const Color surfaceCard = Color(0xFF0D0D12);
  static const Color surfaceElevated = Color(0xFF14141C);
  static const Color surfaceInput = Color(0xFF0A0A0F);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFF1E1E28);
  static const Color borderStrong = Color(0xFF2E2E3D);
  static const Color borderCrimson = Color(0xFF881337);

  // Crimson / Burgundy Primary Accents
  static const Color crimson = Color(0xFFE11D48);
  static const Color crimsonBright = Color(0xFFF43F5E);
  static const Color burgundy = Color(0xFFBE123C);
  static const Color burgundyDeep = Color(0xFF881337);
  static const Color burgundyAbyss = Color(0xFF4C0519);

  // Semantic Telemetry Status Colors
  static const Color statusHigh = Color(0xFF10B981); // Verified / High Confidence
  static const Color statusMedium = Color(0xFFF59E0B); // Probable / Medium
  static const Color statusLow = Color(0xFF71717A); // Informational / Low
  static const Color statusAlert = Color(0xFFE11D48); // Critical Pivot / Match

  // Typography Hierarchy (Dark)
  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF63636E);

  // Light Mode Surfaces (Tactical Paper / Field Mode)
  static const Color lightBg = Color(0xFFF4F4F6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEAEAEF);
  static const Color lightBorder = Color(0xFFD4D4DC);
  static const Color lightTextPrimary = Color(0xFF09090B);
  static const Color lightTextSecondary = Color(0xFF3F3F46);
}

class PanoptesTheme {
  PanoptesTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      surface: PanoptesColors.obsidian,
      primary: PanoptesColors.crimson,
      onPrimary: Colors.white,
      secondary: PanoptesColors.burgundy,
      onSecondary: Colors.white,
      error: Color(0xFFEF4444),
      onSurface: PanoptesColors.textPrimary,
      outline: PanoptesColors.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PanoptesColors.obsidian,
      colorScheme: colorScheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: PanoptesColors.obsidian,
        foregroundColor: PanoptesColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: PanoptesColors.obsidian,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: PanoptesColors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: PanoptesColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PanoptesColors.surfaceInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(
          color: PanoptesColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: PanoptesColors.textMuted,
          fontSize: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PanoptesColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PanoptesColors.crimson, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PanoptesColors.crimson,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PanoptesColors.textPrimary,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: PanoptesColors.borderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PanoptesColors.surfaceElevated,
        selectedColor: PanoptesColors.burgundyDeep,
        side: const BorderSide(color: PanoptesColors.borderSubtle, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        labelStyle: const TextStyle(
          color: PanoptesColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PanoptesColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PanoptesColors.surfaceBase,
        selectedItemColor: PanoptesColors.crimson,
        unselectedItemColor: PanoptesColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      surface: PanoptesColors.lightBg,
      primary: PanoptesColors.burgundy,
      onPrimary: Colors.white,
      secondary: PanoptesColors.crimson,
      onSecondary: Colors.white,
      onSurface: PanoptesColors.lightTextPrimary,
      outline: PanoptesColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PanoptesColors.lightBg,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: PanoptesColors.lightCard,
        foregroundColor: PanoptesColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: PanoptesColors.lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: PanoptesColors.lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PanoptesColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PanoptesColors.lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PanoptesColors.burgundy, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PanoptesColors.burgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PanoptesColors.lightTextPrimary,
          minimumSize: const Size(88, 48),
          side: const BorderSide(color: PanoptesColors.lightBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
