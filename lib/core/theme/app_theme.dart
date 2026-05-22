import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme notifier that persists the user's choice.
class ThemeModeNotifier extends ValueNotifier<ThemeMode> {
  static const _key = 'cyclezen_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      value = ThemeMode.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

/// CycleZen brand theme shared with the web app.
///
/// Palette:
/// Deep Teal #0F4D4D, Route Teal #1D7F78, Mint #58B3A6,
/// Sky #CFE8F6, Sunrise Gold #F5C36A, Cloud White #F5FBFA.
class AppTheme {
  AppTheme._();

  static const Color primaryDark = Color(0xFF0F4D4D);
  static const Color secondaryTeal = Color(0xFF1D7F78);
  static const Color greenAccent = Color(0xFF58B3A6);
  static const Color goldRing = Color(0xFFF5C36A);
  static const Color mintCenter = Color(0xFFEAF7F5);
  static const Color skyAccent = Color(0xFFCFE8F6);
  static const Color cloudWhite = Color(0xFFF5FBFA);

  static const Color _surfaceDark = Color(0xFF082A2B);
  static const Color _backgroundDark = Color(0xFF061D1F);
  static const Color _cardDark = Color(0xFF0D383A);

  static const String _headingFont = 'Poppins';
  static const String _bodyFont = 'Montserrat';

  static LinearGradient get brandGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryDark, secondaryTeal, greenAccent],
      );

  static LinearGradient get sunriseGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skyAccent, cloudWhite, mintCenter],
      );

  static BoxShadow get softBrandShadow => BoxShadow(
        color: primaryDark.withValues(alpha: 0.20),
        blurRadius: 28,
        offset: const Offset(0, 14),
      );

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: _heading(base.displayLarge, 57, FontWeight.w800),
      displayMedium: _heading(base.displayMedium, 45, FontWeight.w800),
      displaySmall: _heading(base.displaySmall, 36, FontWeight.w800),
      headlineLarge: _heading(base.headlineLarge, 32, FontWeight.w800),
      headlineMedium: _heading(base.headlineMedium, 28, FontWeight.w700),
      headlineSmall: _heading(base.headlineSmall, 24, FontWeight.w700),
      titleLarge: _heading(base.titleLarge, 22, FontWeight.w700),
      titleMedium: _heading(base.titleMedium, 16, FontWeight.w600),
      titleSmall: _heading(base.titleSmall, 14, FontWeight.w600),
      bodyLarge: _body(base.bodyLarge, 16),
      bodyMedium: _body(base.bodyMedium, 14),
      bodySmall: _body(base.bodySmall, 12),
      labelLarge: _heading(base.labelLarge, 14, FontWeight.w700),
      labelMedium: _heading(base.labelMedium, 12, FontWeight.w600),
      labelSmall: _heading(base.labelSmall, 11, FontWeight.w600),
    );
  }

  static TextStyle _heading(TextStyle? style, double fontSize, FontWeight weight) {
    return TextStyle(
      fontFamily: _headingFont,
      fontSize: style?.fontSize ?? fontSize,
      fontWeight: style?.fontWeight ?? weight,
      color: style?.color,
      letterSpacing: style?.letterSpacing,
      height: style?.height,
      decoration: style?.decoration,
    );
  }

  static TextStyle _body(TextStyle? style, double fontSize) {
    return TextStyle(
      fontFamily: _bodyFont,
      fontSize: style?.fontSize ?? fontSize,
      fontWeight: style?.fontWeight,
      color: style?.color,
      letterSpacing: style?.letterSpacing,
      height: style?.height,
      decoration: style?.decoration,
    );
  }

  static ThemeData? _cachedLight;
  static ThemeData? _cachedDark;

  static ThemeData get lightTheme {
    _cachedLight ??= _buildLightTheme();
    return _cachedLight!;
  }

  static ThemeData get darkTheme {
    _cachedDark ??= _buildDarkTheme();
    return _cachedDark!;
  }

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryDark,
      brightness: Brightness.light,
      primary: primaryDark,
      secondary: secondaryTeal,
      tertiary: goldRing,
      surface: Colors.white,
    ).copyWith(
      primary: primaryDark,
      secondary: secondaryTeal,
      tertiary: goldRing,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cloudWhite,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: _headingFont,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shadowColor: primaryDark.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: secondaryTeal.withValues(alpha: 0.12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryDark.withValues(alpha: 0.22),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontFamily: _headingFont, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: BorderSide(color: primaryDark.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: secondaryTeal.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: secondaryTeal.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: secondaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryTeal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mintCenter,
        selectedColor: greenAccent.withValues(alpha: 0.22),
        labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 12, color: primaryDark),
        side: BorderSide(color: secondaryTeal.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        contentTextStyle: const TextStyle(fontFamily: _bodyFont, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: secondaryTeal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: greenAccent,
      brightness: Brightness.dark,
      primary: greenAccent,
      secondary: secondaryTeal,
      tertiary: goldRing,
      surface: _surfaceDark,
    ).copyWith(
      primary: greenAccent,
      secondary: secondaryTeal,
      tertiary: goldRing,
      surface: _surfaceDark,
      onPrimary: _backgroundDark,
      onSecondary: Colors.white,
      onTertiary: _backgroundDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundDark,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surfaceDark,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: _headingFont,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _cardDark,
        surfaceTintColor: _cardDark,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: greenAccent.withValues(alpha: 0.15)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: greenAccent,
          foregroundColor: _backgroundDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontFamily: _headingFont, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldRing,
          side: const BorderSide(color: goldRing),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: greenAccent, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: greenAccent,
        foregroundColor: _backgroundDark,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: greenAccent.withValues(alpha: 0.14),
        labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 12),
        side: BorderSide(color: greenAccent.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardDark,
        contentTextStyle: const TextStyle(fontFamily: _bodyFont, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceDark,
        selectedItemColor: greenAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
