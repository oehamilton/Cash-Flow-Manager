import 'package:flutter/material.dart';

import '../../data/money.dart';
import '../../data/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Sticky metric chips: reconciled, today, and 4/8-week forecast lows.
class RegisterMetricsBar extends StatelessWidget {
  const RegisterMetricsBar({
    super.key,
    required this.metrics,
    this.minBalanceCents = 0,
  });

  final RegisterMetrics metrics;

  /// Checking soft floor; trough chips warn in burnt orange when below it.
  final int minBalanceCents;

  static String _dateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

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
                warnBelowMinBalance: true,
                minBalanceCents: minBalanceCents,
              ),
              _MetricChip(
                label: '4-wk low',
                valueKey: const Key('register_metric_trough_4w'),
                cents: metrics.trough4WeeksCents,
                onDate: metrics.trough4WeeksOn,
                dateKey: const Key('register_metric_trough_4w_date'),
                warnBelowMinBalance: true,
                minBalanceCents: minBalanceCents,
              ),
              _MetricChip(
                label: '4–8 wk low',
                valueKey: const Key('register_metric_trough_8w'),
                cents: metrics.trough8WeeksCents,
                onDate: metrics.trough8WeeksOn,
                dateKey: const Key('register_metric_trough_8w_date'),
                warnBelowMinBalance: true,
                minBalanceCents: minBalanceCents,
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
    this.onDate,
    this.dateKey,
    this.warnBelowMinBalance = false,
    this.minBalanceCents = 0,
  });

  final String label;
  final Key valueKey;
  final int? cents;
  final DateTime? onDate;
  final Key? dateKey;
  final bool warnBelowMinBalance;
  final int minBalanceCents;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = cents == null ? '—' : formatCents(cents!);
    final valueColor = _valueColor(cents);
    final dateLabel =
        onDate == null ? null : RegisterMetricsBar._dateLabel(onDate!);

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
            if (dateLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                dateLabel,
                key: dateKey,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontFamily: AppTheme.monoFont,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _valueColor(int? value) {
    if (value == null) {
      return AppColors.onSurfaceMuted;
    }
    if (value < 0) {
      return AppColors.danger;
    }
    if (warnBelowMinBalance &&
        minBalanceCents > 0 &&
        value < minBalanceCents) {
      return AppColors.warningBurnt;
    }
    return AppColors.onSurface;
  }
}
