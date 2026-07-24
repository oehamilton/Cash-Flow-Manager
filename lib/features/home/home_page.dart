import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../theme/app_colors.dart';

/// Temporary landing screen for Phase 0.1 scaffold.
/// Replaced by unlock / register flows in later Phase 0 subphases.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDeep,
              AppColors.backgroundMid,
              Color(0xFF0C3338),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppInfo.name,
                key: const Key('app_name'),
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryBright,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppInfo.versionLabel,
                key: const Key('app_version'),
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Phase 0.1 scaffold — setup wizard and register come next.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
