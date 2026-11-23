import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Shared colors for grouped surfaces and measured signals.
class AppColors {
  AppColors._();

  // Semantic accents for measured signals. No invented goal rings or scores.
  static const stability = Color(0xFFFF375F); // "Move" red-pink
  static const cadence = Color(0xFF217A35); // "Exercise" green
  static const safety = Color(0xFF007FAD); // "Stand" cyan

  static const warning = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF453A);
  static const success = Color(0xFF217A35);
  static const brand = Color(0xFF0066CC);
  static const ink = Color(0xFF1C1C1E);
  static const coral = Color(0xFFC94C3A);
  static const lime = Color(0xFFD1EF72);
  static const mint = Color(0xFFEAF2FF);

  static const lightBackground = Color(0xFFF2F2F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF000000);
  static const darkCard = Color(0xFF1C1C1E);

  // Light-mode micro-labels need at least 4.5:1 on white cards. iOS's
  // #8E8E93 reaches only about 3.3:1, so the darker #6C6C70 is used.
  static const lightLabelSecondary = Color(0xFF6C6C70);
  static const darkLabelSecondary = Color(0xFF98989F);
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light ? AppColors.ink : Colors.white;
    // Start from the typography for this brightness. Without it every style
    // not overridden below (bodySmall, labelLarge, ...) stays black and is
    // invisible on dark cards.
    final platform = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return platform
        .apply(fontFamily: 'NivaSans', bodyColor: base, displayColor: base)
        .copyWith(
          headlineLarge: TextStyle(
              fontFamily: 'NivaSans',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.1,
              color: base),
          titleSmall: TextStyle(
              fontFamily: 'NivaSans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: base),
          // Measured values and test clocks.
          displayLarge: TextStyle(
            fontFamily: 'NivaSans',
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: base,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'NivaSans',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: base,
          ),
          titleMedium: TextStyle(
            fontFamily: 'NivaSans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: base,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'NivaSans',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.3,
            color: base,
          ),
          // Captions and helper text: quieter than body text, still well above
          // 4.5:1 in both themes.
          bodySmall: TextStyle(
            fontFamily: 'NivaSans',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: base.withValues(alpha: 0.75),
          ),
          labelSmall: TextStyle(
            fontFamily: 'NivaSans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: brightness == Brightness.light
                ? AppColors.lightLabelSecondary
                : AppColors.darkLabelSecondary,
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
      scaffoldBackgroundColor:
          isLight ? AppColors.lightBackground : AppColors.darkBackground,
      cardColor: isLight ? AppColors.lightCard : AppColors.darkCard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: brightness,
        surface: isLight ? AppColors.lightCard : AppColors.darkCard,
      ).copyWith(
          primary: isLight ? AppColors.brand : const Color(0xFFA9D4FF),
          onPrimary: isLight ? Colors.white : const Color(0xFF102B46),
          secondary: AppColors.coral,
          onSecondary: AppColors.ink),
      // iOS-style push with parallax and edge swipe back on both platforms.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: isLight ? AppColors.mint : const Color(0xFF214868),
        labelTextStyle:
            WidgetStatePropertyAll(_textTheme(brightness).labelSmall),
      ),
      textTheme: _textTheme(brightness),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor:
              isLight ? AppColors.lightBackground : AppColors.darkCard,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightCard : AppColors.darkCard,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            (isLight ? AppColors.lightBackground : AppColors.darkBackground)
                .withValues(alpha: 0.9),
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
