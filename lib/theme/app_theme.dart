import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple Health-inspired design tokens.
///
/// This intentionally does NOT reuse the web app's indigo/slate palette.
/// Apple Health's visual language is built from three ideas this file
/// captures directly:
///   1. Grouped, layered backgrounds (systemGroupedBackground + white/near
///      black cards) instead of one flat page background.
///   2. A small set of vivid, saturated "ring" colors reserved for the
///      three headline metrics, kept out of everything else so they stay
///      meaningful at a glance.
///   3. Confident, heavy display type for hero numbers, dropping to quiet
///      uppercase micro-labels for context - never mid-weight in between.
class AppColors {
  AppColors._();

  // Ring trio - mirrors Apple's Move / Exercise / Stand rings, remapped to
  // this app's three headline signals.
  static const stability = Color(0xFFFF375F); // "Move" red-pink
  static const cadence = Color(0xFF9AE22B); // "Exercise" green
  static const safety = Color(0xFF00E5FF); // "Stand" cyan

  static const warning = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF453A);
  static const success = Color(0xFF32D74B);
  static const brand = Color(0xFF415AEE); // carried over from GaitGuard Nexus branding

  static const lightBackground = Color(0xFFF2F2F7); // systemGroupedBackground
  static const lightCard = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF000000);
  static const darkCard = Color(0xFF1C1C1E);

  static const lightLabelSecondary = Color(0xFF8E8E93);
  static const darkLabelSecondary = Color(0xFF98989F);
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light ? Colors.black : Colors.white;
    return GoogleFonts.interTextTheme().copyWith(
      // "Today" hero numbers - the 92, the step count, the big ring value.
      displayLarge: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: base,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: base,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: base,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: base,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: brightness == Brightness.light ? AppColors.lightLabelSecondary : AppColors.darkLabelSecondary,
      ),
    );
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isLight ? AppColors.lightBackground : AppColors.darkBackground,
      cardColor: isLight ? AppColors.lightCard : AppColors.darkCard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: brightness,
        surface: isLight ? AppColors.lightCard : AppColors.darkCard,
      ),
      textTheme: _textTheme(brightness),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: (isLight ? AppColors.lightBackground : AppColors.darkBackground).withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: isLight ? Colors.black : Colors.white,
      ),
      dividerColor: isLight ? const Color(0xFFE5E5EA) : const Color(0xFF2C2C2E),
    );
  }
}

/// Standard spring curve used across the app's implicit animations, tuned
/// to feel like Apple Health's ring-fill / card-reflow motion rather than a
/// generic Material ease curve.
class AppMotion {
  AppMotion._();

  static const Curve springCurve = Curves.easeOutCubic;
  static const Duration medium = Duration(milliseconds: 420);
  static const Duration fast = Duration(milliseconds: 220);
}
