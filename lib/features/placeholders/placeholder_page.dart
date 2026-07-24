import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Shared placeholder body for shell destinations not yet implemented.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.phaseHint,
  });

  final String title;
  final String subtitle;
  final String phaseHint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: textTheme.bodyLarge),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                color: AppColors.surface.withValues(alpha: 0.6),
              ),
              child: Text(
                phaseHint,
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: AppColors.primaryBright,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
