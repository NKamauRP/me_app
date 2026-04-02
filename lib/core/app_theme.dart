import 'package:flutter/material.dart';

enum AppThemePreset {
  calm,
  focus,
  energy,
  nature,
  night,
}

class AppThemePalette {
  const AppThemePalette({
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
  static const Map<AppThemePreset, AppThemePalette> palettes =
      <AppThemePreset, AppThemePalette>{
    AppThemePreset.calm: AppThemePalette(
      seed: Color(0xFF1D7A72),
      accent: Color(0xFFF4B942),
      surface: Color(0xFFFFFBF6),
      scaffold: Color(0xFFF8F5F0),
      backgroundTop: Color(0xFFF6EEE6),
      backgroundBottom: Color(0xFFF7F8F4),
      heroTop: Color(0xFF1E766F),
      heroBottom: Color(0xFF285B7D),
      glassTint: Color(0xCCFFFFFF),
      textPrimary: Color(0xFF102321),
      textMuted: Color(0xFF5E6866),
    ),
    AppThemePreset.focus: AppThemePalette(
      seed: Color(0xFF635BFF),
      accent: Color(0xFFE08BFF),
      surface: Color(0xFF141725),
      scaffold: Color(0xFF0E1120),
      backgroundTop: Color(0xFF101223),
      backgroundBottom: Color(0xFF191B31),
      heroTop: Color(0xFF403E8F),
      heroBottom: Color(0xFF1F2245),
      glassTint: Color(0xB3171B31),
      textPrimary: Color(0xFFF5F3FF),
      textMuted: Color(0xFFB7B8D8),
    ),
    AppThemePreset.energy: AppThemePalette(
      seed: Color(0xFFEF7D32),
      accent: Color(0xFFFFD166),
      surface: Color(0xFFFFFAF5),
      scaffold: Color(0xFFFFF4E8),
      backgroundTop: Color(0xFFFFF0E0),
      backgroundBottom: Color(0xFFFFF8F0),
      heroTop: Color(0xFFEF7D32),
      heroBottom: Color(0xFFF29A3F),
      glassTint: Color(0xCCFFFFFF),
      textPrimary: Color(0xFF382011),
      textMuted: Color(0xFF7B5A46),
    ),
    AppThemePreset.nature: AppThemePalette(
      seed: Color(0xFF3F8F5D),
      accent: Color(0xFFCEDF73),
      surface: Color(0xFFF8FCF4),
      scaffold: Color(0xFFF3F8ED),
      backgroundTop: Color(0xFFE8F2E1),
      backgroundBottom: Color(0xFFF6FBF0),
      heroTop: Color(0xFF3F8F5D),
      heroBottom: Color(0xFF295F48),
      glassTint: Color(0xCCFFFFFF),
      textPrimary: Color(0xFF162B20),
      textMuted: Color(0xFF597064),
    ),
    AppThemePreset.night: AppThemePalette(
      seed: Color(0xFF2C6AA0),
      accent: Color(0xFF8ED7FF),
      surface: Color(0xFF111B26),
      scaffold: Color(0xFF09111A),
      backgroundTop: Color(0xFF0A121D),
      backgroundBottom: Color(0xFF111E2C),
      heroTop: Color(0xFF143A5A),
      heroBottom: Color(0xFF0F2437),
      glassTint: Color(0xB3142436),
      textPrimary: Color(0xFFEAF4FF),
      textMuted: Color(0xFFA2B8CC),
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

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.scaffold,
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: -0.8,
          color: palette.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: palette.textMuted,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.textPrimary,
        contentTextStyle: TextStyle(color: palette.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.glassTint.withValues(alpha: isDark ? 0.56 : 0.92),
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: palette.seed, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.seed.withValues(alpha: 0.18),
      ),
    );
  }

  static AppThemePalette paletteOf(AppThemePreset preset) =>
      palettes[preset] ?? palettes[AppThemePreset.calm]!;

  static String labelFor(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.calm:
        return 'Calm';
      case AppThemePreset.focus:
        return 'Focus';
      case AppThemePreset.energy:
        return 'Energy';
      case AppThemePreset.nature:
        return 'Nature';
      case AppThemePreset.night:
        return 'Night';
    }
  }
}
