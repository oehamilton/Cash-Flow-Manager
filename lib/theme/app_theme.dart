import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base.copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.backgroundDeep,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.backgroundMid,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDeep,
      textTheme: Typography.material2021(platform: TargetPlatform.windows)
          .white
          .apply(
            bodyColor: AppColors.onSurface,
            displayColor: AppColors.onSurface,
          ),
    );
  }
}
