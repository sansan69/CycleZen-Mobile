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

/// CycleZen brand theme — derived from the emblem logo.
///
/// Fonts are bundled locally (no network fetch at startup).
/// ThemeData is cached as static fields to avoid recomputation on every access.
///
/// Extracted from emblem: #02494D (dark teal), #257A77 (medium teal),
/// #359780 (green-teal), #ECC382 (gold ring), #CAE7E2 (mint center),
/// #DDEFFB (sky accent).
class AppTheme {
  AppTheme._(); // prevent instantiation

  // ── Emblem-extracted brand palette ──
  static const Color primaryDark = Color(0xFF02494D);
  static const Color secondaryTeal = Color(0xFF257A77);
  static const Color greenAccent = Color(0xFF359780);
  static const Color goldRing = Color(0xFFECC382);
  static const Color mintCenter = Color(0xFFCAE7E2);
  static const Color skyAccent = Color(0xFFDDEFFB);

  // Dark mode surfaces
  static const Color _surfaceDark = Color(0xFF011A1C);
  static const Color _backgroundDark = Color(0xFF001214);
  static const Color _cardDark = Color(0xFF013235);

  // ── Font families (bundled locally) ──
  static const String _headingFont = 'Poppins';
  static const String _bodyFont = 'Montserrat';

  /// Build a TextTheme using bundled Poppins (headlines) + Montserrat (body).
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge:   _heading(base.displayLarge,   57),
      displayMedium:  _heading(base.displayMedium,  45),
      displaySmall:   _heading(base.displaySmall,   36),
      headlineLarge:  _heading(base.headlineLarge,  32),
      headlineMedium: _heading(base.headlineMedium, 28),
      headlineSmall:  _heading(base.headlineSmall,  24),
      titleLarge:     _heading(base.titleLarge,     22),
      titleMedium:    _heading(base.titleMedium,    16),
      titleSmall:     _heading(base.titleSmall,     14),
      bodyLarge:      _body(base.bodyLarge,        16),
      bodyMedium:     _body(base.bodyMedium,       14),
      bodySmall:      _body(base.bodySmall,        12),
      labelLarge:     _heading(base.labelLarge,     14),
      labelMedium:    _heading(base.labelMedium,    12),
      labelSmall:     _heading(base.labelSmall,     11),
    );
  }

  static TextStyle _heading(TextStyle? style, double fontSize) {
    return TextStyle(
      fontFamily: _headingFont,
      fontSize: style?.fontSize ?? fontSize,
      fontWeight: style?.fontWeight,
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

  // ── Cached ThemeData (computed once, reused forever) ──

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
      secondary: secondaryTeal,
      tertiary: goldRing,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: _headingFont,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: _headingFont, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryTeal,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryDark.withValues(alpha: 0.1),
        labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryDark,
      brightness: Brightness.dark,
      secondary: secondaryTeal,
      tertiary: goldRing,
      surface: _surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(surface: _surfaceDark),
      scaffoldBackgroundColor: _backgroundDark,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _surfaceDark,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: _headingFont,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: _headingFont, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldRing,
          side: const BorderSide(color: goldRing),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondaryTeal, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryTeal,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryDark.withValues(alpha: 0.3),
        labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceDark,
        selectedItemColor: secondaryTeal,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
