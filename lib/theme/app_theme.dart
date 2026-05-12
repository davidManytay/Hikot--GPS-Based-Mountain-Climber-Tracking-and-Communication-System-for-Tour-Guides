import 'package:flutter/material.dart';

class HikotColors {
  static const Color darkBackground = Color(0xFF020617);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceLight = Color(0xFF1E293B);

  static const Color primary = Color(0xFF334155);
  static const Color accent = Color(0xFF475569);
  /// Brighter accent for focus rings and key actions (readable on dark surfaces).
  static const Color accentTeal = Color(0xFF2DD4BF);

  static const Color success = Color(0xFF0D9488);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color muted = Color(0xFF1E293B);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
}

class HikotTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: HikotColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: HikotColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: HikotColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: HikotColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: HikotColors.textSecondary,
    letterSpacing: 1.2,
    height: 1.2,
  );

  static const TextStyle tacticalValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: HikotColors.textPrimary,
    letterSpacing: -1,
    height: 1.1,
  );

  /// Dense tables / roster rows — still above minimum tap/read targets where used in lists.
  static const TextStyle meta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: HikotColors.textMuted,
    height: 1.3,
  );
}

class HikotTheme {
  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: HikotColors.accentTeal,
      onPrimary: Color(0xFF0F172A),
      secondary: HikotColors.accent,
      onSecondary: HikotColors.textPrimary,
      surface: HikotColors.surface,
      onSurface: HikotColors.textPrimary,
      error: HikotColors.error,
      onError: Colors.white,
      outline: Color(0xFF334155),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: HikotColors.darkBackground,
      colorScheme: scheme,
      textTheme: const TextTheme(
        headlineLarge: HikotTextStyles.h1,
        headlineMedium: HikotTextStyles.h2,
        headlineSmall: HikotTextStyles.h2,
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: HikotColors.textPrimary,
        ),
        bodyLarge: HikotTextStyles.body,
        bodyMedium: HikotTextStyles.body,
        bodySmall: HikotTextStyles.bodySecondary,
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: HikotColors.textPrimary,
        ),
        labelSmall: HikotTextStyles.label,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HikotColors.surface,
        foregroundColor: HikotColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: HikotColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: HikotColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HikotColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HikotColors.surfaceLight,
        contentTextStyle: const TextStyle(
          color: HikotColors.textPrimary,
          fontSize: 15,
          height: 1.35,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        hintStyle: TextStyle(color: HikotColors.textMuted.withOpacity(0.85)),
        labelStyle: const TextStyle(color: HikotColors.textSecondary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HikotColors.accentTeal, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: Colors.white,
          backgroundColor: HikotColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0D9488),
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFDC2626),
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        headlineLarge: HikotTextStyles.h1.copyWith(color: const Color(0xFF0F172A)),
        headlineMedium: HikotTextStyles.h2.copyWith(color: const Color(0xFF0F172A)),
        bodyLarge: HikotTextStyles.body.copyWith(color: const Color(0xFF334155)),
        bodyMedium: HikotTextStyles.body.copyWith(color: const Color(0xFF334155)),
        bodySmall: HikotTextStyles.bodySecondary.copyWith(color: const Color(0xFF475569)),
        labelSmall: HikotTextStyles.label.copyWith(color: const Color(0xFF64748B)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
    );
  }
}
