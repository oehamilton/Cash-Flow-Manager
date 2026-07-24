import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const String displayFont = 'Rajdhani';
  static const String monoFont = 'IBMPlexMono';

  static ThemeData dark() {
    final baseText = Typography.material2021(platform: TargetPlatform.windows)
        .white
        .apply(
          fontFamily: displayFont,
          bodyColor: AppColors.onSurface,
          displayColor: AppColors.onSurface,
        );

    final textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.primaryBright,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.primaryBright,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceMuted,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: AppColors.onSurfaceMuted,
        height: 1.4,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );

    final colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.backgroundDeep,
      secondary: AppColors.primaryBright,
      onSecondary: AppColors.backgroundDeep,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.danger,
      onError: AppColors.onSurface,
      outline: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDeep,
      textTheme: textTheme,
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.rail,
        indicatorColor: AppColors.surfaceElevated,
        selectedIconTheme: IconThemeData(color: AppColors.primaryBright),
        unselectedIconTheme: IconThemeData(color: AppColors.onSurfaceMuted),
        selectedLabelTextStyle: TextStyle(
          fontFamily: displayFont,
          color: AppColors.primaryBright,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: displayFont,
          color: AppColors.onSurfaceMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
    );
  }
}
