import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Compact key for forecast row colors (Phase 3.3 visuals gate).
class RegisterRowLegend extends StatelessWidget {
  const RegisterRowLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.onSurfaceMuted,
          fontFamily: AppTheme.monoFont,
        );
    return Padding(
      key: const Key('register_row_legend'),
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _swatch(AppColors.rowCleared, 'Cleared', style),
          _swatch(AppColors.rowUnclearedPast, 'Open', style),
          _swatch(AppColors.rowAutoFuture, 'Auto future', style),
          _swatch(AppColors.rowManualFuture, 'Manual future', style),
        ],
      ),
    );
  }

  Widget _swatch(Color color, String label, TextStyle? style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: AppColors.outline),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}
