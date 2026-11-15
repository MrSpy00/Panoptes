import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Panoptes Tactical Crimson-Obsidian Design System
/// Zero AI-Slop: Pure #000000 AMOLED canvas in dark mode, high-contrast tactical paper in light mode,
/// sharp 1px architectural borders, Crimson-Burgundy (#E11D48 / #BE123C / #881337) accent hierarchy.
class PanoptesColors {
  PanoptesColors._();

  // Obsidian Dark Surfaces
  static const Color obsidian = Color(0xFF000000);
  static const Color surfaceBase = Color(0xFF07070A);
  static const Color surfaceCard = Color(0xFF0D0D12);
  static const Color surfaceElevated = Color(0xFF14141C);
  static const Color surfaceInput = Color(0xFF0A0A0F);

  // Borders & Dividers (Dark)
  static const Color borderSubtle = Color(0xFF1E1E28);
  static const Color borderStrong = Color(0xFF2E2E3D);
  static const Color borderCrimson = Color(0xFF881337);

  // Crimson / Burgundy Primary Accents
  static const Color crimson = Color(0xFFE11D48);
  static const Color crimsonBright = Color(0xFFFB7185);
  static const Color crimsonDeep = Color(0xFFBE123C);
  static const Color burgundy = Color(0xFFBE123C);
  static const Color burgundyDeep = Color(0xFF881337);
  static const Color burgundyAbyss = Color(0xFF3F0617);

  // Semantic Telemetry Status Colors
  static const Color statusHigh = Color(0xFF10B981);
  static const Color statusMedium = Color(0xFFF59E0B);
  static const Color statusLow = Color(0xFF71717A);
  static const Color statusAlert = Color(0xFFE11D48);

  // Typography Hierarchy (Dark)
  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Light Mode Surfaces (Tactical Daylight / Field Mode)
  static const Color lightBg = Color(0xFFF3F4F6);
  static const Color lightBase = Color(0xFFE5E7EB);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF9FAFB);
  static const Color lightBorder = Color(0xFFD1D5DB);
  static const Color lightBorderStrong = Color(0xFF9CA3AF);
  static const Color lightCrimsonBorder = Color(0xFFFDA4AF);
  static const Color lightCrimsonTint = Color(0xFFFFE4E6);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextMuted = Color(0xFF6B7280);
}

/// Dynamic theme-aware palette so every card, badge, border, and text color
/// renders with flawless contrast in BOTH Obsidian Dark Mode and Tactical Light Mode.
class PanoptesPalette {
  final bool isDark;
  final Color bg;
  Color get obsidian => bg;
  final Color surfaceBase;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceInput;
  final Color borderSubtle;
  final Color borderStrong;
  final Color borderCrimson;
  final Color crimson;
  final Color crimsonText;
  final Color crimsonTintBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color statusHigh;

  const PanoptesPalette({
    required this.isDark,
    required this.bg,
    required this.surfaceBase,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceInput,
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderCrimson,
    required this.crimson,
    required this.crimsonText,
    required this.crimsonTintBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.statusHigh,
  });

  static const PanoptesPalette dark = PanoptesPalette(
    isDark: true,
    bg: PanoptesColors.obsidian,
    surfaceBase: PanoptesColors.surfaceBase,
    surfaceCard: PanoptesColors.surfaceCard,
    surfaceElevated: PanoptesColors.surfaceElevated,
    surfaceInput: PanoptesColors.surfaceInput,
    borderSubtle: PanoptesColors.borderSubtle,
    borderStrong: PanoptesColors.borderStrong,
    borderCrimson: PanoptesColors.borderCrimson,
    crimson: PanoptesColors.crimson,
    crimsonText: PanoptesColors.crimsonBright,
    crimsonTintBg: PanoptesColors.burgundyAbyss,
    textPrimary: PanoptesColors.textPrimary,
    textSecondary: PanoptesColors.textSecondary,
    textMuted: PanoptesColors.textMuted,
    statusHigh: PanoptesColors.statusHigh,
  );

  static const PanoptesPalette light = PanoptesPalette(
    isDark: false,
    bg: PanoptesColors.lightBg,
    surfaceBase: PanoptesColors.lightBase,
    surfaceCard: PanoptesColors.lightCard,
    surfaceElevated: PanoptesColors.lightElevated,
    surfaceInput: PanoptesColors.lightCard,
    borderSubtle: PanoptesColors.lightBorder,
    borderStrong: PanoptesColors.lightBorderStrong,
    borderCrimson: PanoptesColors.burgundy,
    crimson: PanoptesColors.burgundy,
    crimsonText: PanoptesColors.burgundyDeep,
    crimsonTintBg: PanoptesColors.lightCrimsonTint,
    textPrimary: PanoptesColors.lightTextPrimary,
    textSecondary: PanoptesColors.lightTextSecondary,
    textMuted: PanoptesColors.lightTextMuted,
    statusHigh: Color(0xFF059669),
  );

  static PanoptesPalette of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
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
      splashFactory: InkRipple.splashFactory,
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        labelStyle: const TextStyle(
          color: PanoptesColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: PanoptesColors.textMuted,
          fontSize: 12,
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
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PanoptesColors.textPrimary,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: const BorderSide(color: PanoptesColors.borderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
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
      surface: PanoptesColors.lightCard,
      primary: PanoptesColors.burgundy,
      onPrimary: Colors.white,
      secondary: PanoptesColors.crimson,
      onSecondary: Colors.white,
      error: Color(0xFFDC2626),
      onSurface: PanoptesColors.lightTextPrimary,
      outline: PanoptesColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PanoptesColors.lightBg,
      colorScheme: colorScheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: PanoptesColors.lightCard,
        foregroundColor: PanoptesColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: PanoptesColors.lightCard,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
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
        fillColor: PanoptesColors.lightElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        labelStyle: const TextStyle(
          color: PanoptesColors.lightTextSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: PanoptesColors.lightTextMuted,
          fontSize: 12,
        ),
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
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PanoptesColors.lightTextPrimary,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: const BorderSide(color: PanoptesColors.lightBorderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PanoptesColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PanoptesColors.lightCard,
        selectedItemColor: PanoptesColors.burgundy,
        unselectedItemColor: PanoptesColors.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
