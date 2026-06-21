import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

// Use bundled font — no network dependency
const _fontFamily = 'IBMPlexSansArabic';

TextStyle _t({
  double? size,
  FontWeight? weight,
  Color? color,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: _fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

class AppTheme {
  static TextTheme get _textTheme => TextTheme(
        displayLarge:  _t(size: 32, weight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
        displayMedium: _t(size: 24, weight: FontWeight.w700, color: AppColors.textPrimary),
        headlineLarge: _t(size: 22, weight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium:_t(size: 19, weight: FontWeight.w700, color: AppColors.textPrimary),
        headlineSmall: _t(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge:    _t(size: 15, weight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium:   _t(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall:    _t(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge:     _t(size: 15, weight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium:    _t(size: 14, weight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall:     _t(size: 12, weight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge:    _t(size: 15, weight: FontWeight.w700, color: Colors.white),
        labelMedium:   _t(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
        labelSmall:    _t(size: 11, weight: FontWeight.w500, color: AppColors.textHint),
      );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: _t(size: 18, weight: FontWeight.w700, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _t(size: 15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _t(size: 14, weight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: _t(size: 14, color: AppColors.textHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
