import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium design system for DSA Malawi.
/// Custom colors, typography, spacing, and shape schemes.
class AppTheme {
  static const Color seedColor = Color(0xFF1A6B3C);
  static const Color surfaceLight = Color(0xFFF8FAF9);
  static const Color surfaceDark = Color(0xFF111312);

  // ── Spacing system (8px grid) ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ── Border radius ──
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ── Durations ──
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // ── Curves ──
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: isDark ? surfaceDark : surfaceLight,
    );

    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? surfaceDark : surfaceLight,

      // ── Cards ──
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),

      // ── Bottom Navigation ──
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? surfaceDark : surfaceLight,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),

      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          padding: const EdgeInsets.symmetric(horizontal: md + sm, vertical: md - xs),
        ),
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: md, vertical: md - xs),
      ),

      // ── Dividers ──
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}

/// Navigate with a smooth slide transition
extension AppNavigator on BuildContext {
  Future<T?> pushSlide<T>(Widget page) {
    return Navigator.of(this).push<T>(MaterialPageRoute(
      builder: (_) => page,
      fullscreenDialog: true,
    ));
  }

  Future<T?> pushReplaceSlide<T>(Widget page) {
    return Navigator.of(this).pushReplacement<T, dynamic>(MaterialPageRoute(
      builder: (_) => page,
    ));
  }
}
