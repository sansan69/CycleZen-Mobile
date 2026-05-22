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
///
/// Typography: Poppins (headings) + Montserrat (body).
/// All text uses clean dark shadows — no white haze.
class AppTheme {
  AppTheme._();

  // ── Brand palette ──
  static const Color primaryDark = Color(0xFF0F4D4D);
  static const Color secondaryTeal = Color(0xFF1D7F78);
  static const Color greenAccent = Color(0xFF58B3A6);
  static const Color goldRing = Color(0xFFF5C36A);
  static const Color mintCenter = Color(0xFFEAF7F5);
  static const Color skyAccent = Color(0xFFCFE8F6);
  static const Color cloudWhite = Color(0xFFF5FBFA);

  // Dark surfaces
  static const Color surfaceDark = Color(0xFF082A2B);
  static const Color backgroundDark = Color(0xFF061D1F);
  static const Color cardDark = Color(0xFF0D383A);

  // ── Semantic text colors ──
  static const Color textPrimary = Color(0xFF0A1A1C);     // near-black teal
  static const Color textSecondary = Color(0xFF2D5A5C);   // muted dark teal
  static const Color textOnDark = Color(0xFFF5FBFA);      // cloud white
  static const Color textOnDarkMuted = Color(0xFFB8D8D4); // muted mint on dark
  static const Color textHint = Color(0xFF6B8A8C);        // placeholder/secondary

  // ── Font families ──
  static const String _headingFont = 'Poppins';
  static const String _bodyFont = 'Montserrat';

  // ── Text shadows (clean, no white haze) ──

  /// Subtle dark shadow for dark text on light backgrounds.
  static List<Shadow> get textShadowSubtle => const [
        Shadow(
          color: Color(0x18000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  /// Crisp shadow for white/light text on dark backgrounds.
  static List<Shadow> get textShadowOnDark => const [
        Shadow(
          color: Color(0x40000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Strong shadow for hero/display text on variable backgrounds.
  static List<Shadow> get textShadowHero => const [
        Shadow(
          color: Color(0x30000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  // ── Gradients ──
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

  // ── Box shadows ──
  static BoxShadow get softBrandShadow => BoxShadow(
        color: primaryDark.withValues(alpha: 0.20),
        blurRadius: 28,
        offset: const Offset(0, 14),
      );

  static BoxShadow get cardShadow => BoxShadow(
        color: primaryDark.withValues(alpha: 0.10),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );

  static BoxShadow get elevatedShadow => BoxShadow(
        color: primaryDark.withValues(alpha: 0.16),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );

  // ── Text theme builder ──

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge:
          _heading(base.displayLarge, 57, FontWeight.w800, -0.5, 1.12),
      displayMedium:
          _heading(base.displayMedium, 45, FontWeight.w800, -0.3, 1.14),
      displaySmall:
          _heading(base.displaySmall, 36, FontWeight.w800, -0.2, 1.16),
      headlineLarge:
          _heading(base.headlineLarge, 32, FontWeight.w800, -0.4, 1.18),
      headlineMedium:
          _heading(base.headlineMedium, 28, FontWeight.w700, -0.3, 1.20),
      headlineSmall:
          _heading(base.headlineSmall, 24, FontWeight.w700, -0.2, 1.22),
      titleLarge:
          _heading(base.titleLarge, 22, FontWeight.w700, -0.2, 1.25),
      titleMedium:
          _heading(base.titleMedium, 16, FontWeight.w600, 0, 1.30),
      titleSmall:
          _heading(base.titleSmall, 14, FontWeight.w600, 0, 1.30),
      bodyLarge:
          _body(base.bodyLarge, 16, FontWeight.w400, 0, 1.50),
      bodyMedium:
          _body(base.bodyMedium, 14, FontWeight.w400, 0, 1.45),
      bodySmall:
          _body(base.bodySmall, 12, FontWeight.w400, 0, 1.40),
      labelLarge:
          _heading(base.labelLarge, 14, FontWeight.w700, 0.5, 1.25),
      labelMedium:
          _heading(base.labelMedium, 12, FontWeight.w600, 0.5, 1.25),
      labelSmall:
          _heading(base.labelSmall, 11, FontWeight.w600, 0.8, 1.20),
    );
  }

  static TextStyle _heading(
    TextStyle? style,
    double fontSize,
    FontWeight weight,
    double letterSpacing,
    double height,
  ) {
    return TextStyle(
      fontFamily: _headingFont,
      fontSize: style?.fontSize ?? fontSize,
      fontWeight: style?.fontWeight ?? weight,
      letterSpacing: style?.letterSpacing ?? letterSpacing,
      height: style?.height ?? height,
      color: style?.color,
      decoration: style?.decoration,
    );
  }

  static TextStyle _body(
    TextStyle? style,
    double fontSize,
    FontWeight weight,
    double letterSpacing,
    double height,
  ) {
    return TextStyle(
      fontFamily: _bodyFont,
      fontSize: style?.fontSize ?? fontSize,
      fontWeight: style?.fontWeight ?? weight,
      letterSpacing: style?.letterSpacing ?? letterSpacing,
      height: style?.height ?? height,
      color: style?.color,
      decoration: style?.decoration,
    );
  }

  // ── Cached ThemeData ──

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
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
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
        shadowColor: Color(0x40000000),
        titleTextStyle: TextStyle(
          fontFamily: _headingFont,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
          height: 1.2,
          shadows: [
            Shadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shadowColor: primaryDark.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: secondaryTeal.withValues(alpha: 0.12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryDark.withValues(alpha: 0.28),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
            fontFamily: _headingFont,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
            height: 1.2,
            shadows: [
              Shadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: BorderSide(color: primaryDark.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
            fontFamily: _headingFont,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: textHint, fontFamily: _bodyFont),
        labelStyle: const TextStyle(color: textSecondary, fontFamily: _bodyFont),
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
        elevation: 6,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mintCenter,
        selectedColor: greenAccent.withValues(alpha: 0.22),
        labelStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primaryDark,
          letterSpacing: 0.1,
        ),
        side: BorderSide(color: secondaryTeal.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        contentTextStyle: const TextStyle(
          fontFamily: _bodyFont,
          color: Colors.white,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: secondaryTeal,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x180F4D4D),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: primaryDark,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: _bodyFont,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
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
      surface: surfaceDark,
    ).copyWith(
      primary: greenAccent,
      secondary: secondaryTeal,
      tertiary: goldRing,
      surface: surfaceDark,
      onPrimary: backgroundDark,
      onSecondary: Colors.white,
      onTertiary: backgroundDark,
      onSurface: textOnDark,
      onSurfaceVariant: textOnDarkMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        shadowColor: Colors.black54,
        titleTextStyle: TextStyle(
          fontFamily: _headingFont,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
          height: 1.2,
          shadows: [
            Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardDark,
        surfaceTintColor: cardDark,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: greenAccent.withValues(alpha: 0.15)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: greenAccent,
          foregroundColor: backgroundDark,
          elevation: 2,
          shadowColor: greenAccent.withValues(alpha: 0.30),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
            fontFamily: _headingFont,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldRing,
          side: const BorderSide(color: goldRing),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
            fontFamily: _headingFont,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        hintStyle: const TextStyle(
          color: Color(0xFF6B8A8C),
          fontFamily: _bodyFont,
        ),
        labelStyle: const TextStyle(
          color: textOnDarkMuted,
          fontFamily: _bodyFont,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: greenAccent, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: greenAccent,
        foregroundColor: backgroundDark,
        elevation: 6,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: greenAccent.withValues(alpha: 0.14),
        selectedColor: greenAccent.withValues(alpha: 0.28),
        labelStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textOnDark,
          letterSpacing: 0.1,
        ),
        side: BorderSide(color: greenAccent.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: const TextStyle(
          fontFamily: _bodyFont,
          color: Colors.white,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: greenAccent,
        unselectedItemColor: textOnDarkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x20FFFFFF),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: _bodyFont,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
