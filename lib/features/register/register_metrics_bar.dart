import 'package:flutter/material.dart';

import '../../data/money.dart';
import '../../data/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Sticky metric chips: reconciled, today, and forecast trough placeholders.
class RegisterMetricsBar extends StatelessWidget {
  const RegisterMetricsBar({
    super.key,
    required this.metrics,
  });

  final RegisterMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('register_metrics_bar'),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.92),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final chips = [
              _MetricChip(
                label: 'Reconciled',
                valueKey: const Key('register_metric_reconciled'),
                cents: metrics.reconciledCents,
              ),
              _MetricChip(
                label: 'Today',
                valueKey: const Key('register_metric_today'),
                cents: metrics.todayCents,
              ),
              _MetricChip(
                label: '4-wk low',
                valueKey: const Key('register_metric_trough_4w'),
                cents: metrics.trough4WeeksCents,
                placeholder: true,
              ),
              _MetricChip(
                label: '8-wk low',
                valueKey: const Key('register_metric_trough_8w'),
                cents: metrics.trough8WeeksCents,
                placeholder: true,
              ),
            ];
            if (wide) {
              return Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: chips[i]),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final chip in chips)
                  SizedBox(width: 160, child: chip),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.valueKey,
    required this.cents,
    this.placeholder = false,
  });

  final String label;
  final Key valueKey;
  final int? cents;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = cents == null ? '—' : formatCents(cents!);
    final valueColor = cents == null
        ? AppColors.onSurfaceMuted
        : (cents! < 0 ? AppColors.danger : AppColors.onSurface);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.onSurfaceMuted,
                fontFamily: AppTheme.monoFont,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              display,
              key: valueKey,
              style: textTheme.titleLarge?.copyWith(
                fontFamily: AppTheme.monoFont,
                color: valueColor,
              ),
            ),
            if (placeholder) ...[
              const SizedBox(height: 2),
              Text(
                'Forecast soon',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
