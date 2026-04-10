import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemePreset {
  calm,
  focus,
  energy,
  nature,
  night,
}

class AppThemePalette {
  AppThemePalette({
    required this.seed,
    required this.accent,
    required this.surface,
    required this.scaffold,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.heroTop,
    required this.heroBottom,
    required this.glassTint,
    required this.textPrimary,
    required this.textMuted,
  });

  final Color seed;
  final Color accent;
  final Color surface;
  final Color scaffold;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color heroTop;
  final Color heroBottom;
  final Color glassTint;
  final Color textPrimary;
  final Color textMuted;
}

class AppTheme {
  static final Map<AppThemePreset, AppThemePalette> palettes =
      <AppThemePreset, AppThemePalette>{
    AppThemePreset.calm: AppThemePalette(
      seed: Color(0xFF1D7A72),
      accent: Color(0xFFF4B942),
      surface: Color(0xFFFAF9F6), // Warm white (Claude-like)
      scaffold: Color(0xFFF5F2ED), // Soft parchment
      backgroundTop: Color(0xFFFAF9F6),
      backgroundBottom: Color(0xFFF2EEE9),
      heroTop: Color(0xFF1E766F),
      heroBottom: Color(0xFF285B7D),
      glassTint: Color(0xE6FFFFFF),
      textPrimary: Color(0xFF1A1C1C),
      textMuted: Color(0xFF5A5C5C),
    ),
    AppThemePreset.focus: AppThemePalette(
      seed: Color(0xFF4338CA),
      accent: Color(0xFFA78BFA),
      surface: Color(0xFF111827),
      scaffold: Color(0xFF0F172A),
      backgroundTop: Color(0xFF0F172A),
      backgroundBottom: Color(0xFF1E293B),
      heroTop: Color(0xFF312E81),
      heroBottom: Color(0xFF1E1B4B),
      glassTint: Color(0xD91E293B),
      textPrimary: Color(0xFFF9FAFB),
      textMuted: Color(0xFF94A3B8),
    ),
    AppThemePreset.energy: AppThemePalette(
      seed: Color(0xFFC2410C),
      accent: Color(0xFFFDBA74),
      surface: Color(0xFFFFF7ED),
      scaffold: Color(0xFFFFFAF5),
      backgroundTop: Color(0xFFFFFAF5),
      backgroundBottom: Color(0xFFFFF1E2),
      heroTop: Color(0xFF9A3412),
      heroBottom: Color(0xFFC2410C),
      glassTint: Color(0xE6FFFFFF),
      textPrimary: Color(0xFF431407),
      textMuted: Color(0xFF9A3412).withValues(alpha: 0.7),
    ),
    AppThemePreset.nature: AppThemePalette(
      seed: Color(0xFF166534),
      accent: Color(0xFFBBF7D0),
      surface: Color(0xFFF0FDF4),
      scaffold: Color(0xFFF7FEE7),
      backgroundTop: Color(0xFFF7FEE7),
      backgroundBottom: Color(0xFFECFCCB),
      heroTop: Color(0xFF14532D),
      heroBottom: Color(0xFF166534),
      glassTint: Color(0xE6FFFFFF),
      textPrimary: Color(0xFF14532D),
      textMuted: Color(0xFF166534).withValues(alpha: 0.7),
    ),
    AppThemePreset.night: AppThemePalette(
      seed: Color(0xFF1E3A8A),
      accent: Color(0xFF93C5FD),
      surface: Color(0xFF0F172A),
      scaffold: Color(0xFF020617),
      backgroundTop: Color(0xFF020617),
      backgroundBottom: Color(0xFF0F172A),
      heroTop: Color(0xFF172554),
      heroBottom: Color(0xFF1E3A8A),
      glassTint: Color(0xD90F172A),
      textPrimary: Color(0xFFF1F5F9),
      textMuted: Color(0xFF64748B),
    ),
  };

  static ThemeData themeFor(AppThemePreset preset) {
    final palette = paletteOf(preset);
    final isDark = preset == AppThemePreset.focus || preset == AppThemePreset.night;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: palette.surface,
    ).copyWith(
      primary: palette.seed,
      secondary: palette.accent,
      surface: palette.surface,
    );

    // Claude / Notion style typography
    final sansFont = GoogleFonts.interTextTheme();
    final serifFont = GoogleFonts.loraTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.scaffold,
      
      // Merge Inter for UI and Lora for Content
      textTheme: sansFont.copyWith(
        displaySmall: serifFont.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: serifFont.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        titleLarge: sansFont.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: sansFont.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        bodyLarge: serifFont.bodyLarge?.copyWith(
          fontSize: 17,
          height: 1.6, // Breathable like Claude
          color: palette.textPrimary,
        ),
        bodyMedium: sansFont.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
          color: palette.textMuted,
        ),
        labelSmall: sansFont.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: palette.textMuted,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.textPrimary,
        contentTextStyle: GoogleFonts.inter(color: palette.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: palette.textPrimary.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.textPrimary.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.textPrimary.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.seed, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static AppThemePalette paletteOf(AppThemePreset preset) =>
      palettes[preset] ?? palettes[AppThemePreset.calm]!;

  static String labelFor(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.calm: return 'Calm';
      case AppThemePreset.focus: return 'Focus';
      case AppThemePreset.energy: return 'Energy';
      case AppThemePreset.nature: return 'Nature';
      case AppThemePreset.night: return 'Night';
    }
  }
}
