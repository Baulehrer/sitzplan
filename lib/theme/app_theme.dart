import 'package:flutter/material.dart';

abstract final class UiBreakpoints {
  static const compact = 600.0;
  static const expanded = 1100.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

abstract final class AppColors {
  static const boardBlue = Color(0xFF17324D);
  static const paper = Color(0xFFF6F8F5);
  static const chalk = Color(0xFFE8F0E8);
  static const markerYellow = Color(0xFFF2B84B);
  static const correctionRed = Color(0xFFC74B50);
  static const ink = Color(0xFF16202A);
}

class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? const Color(0xFF9EC9EF) : AppColors.boardBlue,
      onPrimary: dark ? AppColors.ink : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF284A68)
          : const Color(0xFFDCEAF5),
      onPrimaryContainer: dark ? const Color(0xFFE7F3FF) : AppColors.boardBlue,
      secondary: AppColors.markerYellow,
      onSecondary: AppColors.ink,
      secondaryContainer: dark
          ? const Color(0xFF5B451B)
          : const Color(0xFFFFE7AF),
      onSecondaryContainer: dark ? const Color(0xFFFFE7AF) : AppColors.ink,
      tertiary: dark ? const Color(0xFFAED8B6) : const Color(0xFF376B4B),
      onTertiary: dark ? AppColors.ink : Colors.white,
      error: dark ? const Color(0xFFFFB3B5) : AppColors.correctionRed,
      onError: dark ? AppColors.ink : Colors.white,
      surface: dark ? const Color(0xFF111A22) : AppColors.paper,
      onSurface: dark ? const Color(0xFFE8EEF3) : AppColors.ink,
      surfaceContainerLowest: dark
          ? const Color(0xFF0C141B)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark
          ? const Color(0xFF17232D)
          : const Color(0xFFEEF3F2),
      surfaceContainer: dark
          ? const Color(0xFF1B2833)
          : const Color(0xFFE6ECEA),
      surfaceContainerHigh: dark
          ? const Color(0xFF22313D)
          : const Color(0xFFDCE5E2),
      surfaceContainerHighest: dark
          ? const Color(0xFF2B3B47)
          : const Color(0xFFD1DDDA),
      onSurfaceVariant: dark
          ? const Color(0xFFBBC8D1)
          : const Color(0xFF52616A),
      outline: dark ? const Color(0xFF82919B) : const Color(0xFF6D7B82),
      outlineVariant: dark ? const Color(0xFF3A4A55) : const Color(0xFFC4CFCC),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? AppColors.paper : AppColors.ink,
      onInverseSurface: dark ? AppColors.ink : AppColors.paper,
      inversePrimary: dark ? AppColors.boardBlue : const Color(0xFF9EC9EF),
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: 'SitzplanDisplay',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'SitzplanDisplay',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'SitzplanDisplay',
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: 'SitzplanDisplay',
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontFamily: 'SitzplanDisplay',
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
