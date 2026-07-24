import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/account_history.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// 12-month balance line + interest bars (Phase 4.2 chart style gate).
class AccountHistoryChart extends StatelessWidget {
  const AccountHistoryChart({
    super.key,
    required this.points,
  });

  final List<AccountMonthPoint> points;

  static const _axisWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasInterest = points.any((p) => p.interestPaidCents > 0);
    final latest = points.last;
    final scale = _balanceScale(points);

    return DecoratedBox(
      key: const Key('account_history_chart'),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.85),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Last 12 months',
                  style: textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  'Balance ${formatCents(latest.balanceCents)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.primaryBright,
                    fontFamily: AppTheme.monoFont,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _legendDot(AppColors.primaryBright, 'Balance'),
                if (hasInterest)
                  _legendDot(AppColors.warning, 'Interest paid'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _HistoryChartPainter(
                  points: points,
                  minY: scale.minY,
                  maxY: scale.maxY,
                  ticks: scale.ticks,
                  leftPad: _axisWidth,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: _axisWidth),
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Text(
                      i % 2 == 0 || i == points.length - 1
                          ? points[i].shortLabel
                          : '',
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                        fontFamily: AppTheme.monoFont,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 12,
            fontFamily: AppTheme.monoFont,
          ),
        ),
      ],
    );
  }
}

class _BalanceScale {
  const _BalanceScale({
    required this.minY,
    required this.maxY,
    required this.ticks,
  });

  final double minY;
  final double maxY;
  final List<double> ticks;
}

/// Axis quantum: nearest $10 (1000 cents).
const axisTenDollarsCents = 1000;

_BalanceScale _balanceScale(List<AccountMonthPoint> points) {
  final balances = points.map((p) => p.balanceCents.toDouble()).toList();
  var minY = balances.reduce(math.min);
  var maxY = balances.reduce(math.max);
  if ((maxY - minY).abs() < axisTenDollarsCents) {
    minY -= axisTenDollarsCents;
    maxY += axisTenDollarsCents;
  }
  final pad = (maxY - minY) * 0.12;
  minY -= pad;
  maxY += pad;

  final tickStep = _axisTickStepCents(maxY - minY);
  var minTick = (minY / tickStep).floor() * tickStep;
  var maxTick = (maxY / tickStep).ceil() * tickStep;
  if (minTick == maxTick) {
    minTick -= tickStep;
    maxTick += tickStep;
  }

  final ticks = <double>[
    for (var v = minTick; v <= maxTick; v += tickStep) v.toDouble(),
  ];
  return _BalanceScale(
    minY: minTick.toDouble(),
    maxY: maxTick.toDouble(),
    ticks: ticks,
  );
}

/// Step size in cents: a multiple of $10 that yields roughly 4 axis ticks.
int _axisTickStepCents(double spanCents) {
  final rough = spanCents / 3;
  const multiples = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000];
  var units = multiples.last;
  for (final m in multiples) {
    if (m * axisTenDollarsCents >= rough) {
      units = m;
      break;
    }
  }
  return units * axisTenDollarsCents;
}

/// Axis dollar label: nearest $10, no cents.
String formatAxisCents(int cents) {
  final rounded =
      ((cents / axisTenDollarsCents).round()) * axisTenDollarsCents;
  final formatted = formatCents(rounded);
  if (formatted.endsWith('.00')) {
    return formatted.substring(0, formatted.length - 3);
  }
  return formatted;
}

class _HistoryChartPainter extends CustomPainter {
  _HistoryChartPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.ticks,
    required this.leftPad,
  });

  final List<AccountMonthPoint> points;
  final double minY;
  final double maxY;
  final List<double> ticks;
  final double leftPad;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final plotWidth = math.max(0.0, size.width - leftPad);
    final balances = points.map((p) => p.balanceCents.toDouble()).toList();
    final interests = points.map((p) => p.interestPaidCents.toDouble()).toList();
    final maxInterest = interests.fold<double>(0, math.max);
    final range = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY);

    double xAt(int i) {
      if (points.length == 1) {
        return leftPad + plotWidth / 2;
      }
      return leftPad + plotWidth * i / (points.length - 1);
    }

    double balanceY(double value) {
      final t = (value - minY) / range;
      return size.height * (1 - t);
    }

    final gridPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final zeroPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    final labelStyle = ui.TextStyle(
      color: AppColors.onSurfaceMuted,
      fontSize: 10,
      fontFamily: AppTheme.monoFont,
    );

    for (final tick in ticks) {
      final y = balanceY(tick);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final label = formatAxisCents(tick.round());
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.right))
        ..pushStyle(labelStyle)
        ..addText(label);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: leftPad - 6));
      canvas.drawParagraph(
        paragraph,
        Offset(0, y - paragraph.height / 2),
      );
    }

    // Emphasize zero when the balance range crosses it.
    if (minY < 0 && maxY > 0) {
      final zeroY = balanceY(0);
      canvas.drawLine(
        Offset(leftPad, zeroY),
        Offset(size.width, zeroY),
        zeroPaint,
      );
    }

    // Interest bars use an independent bottom band so debt balances don't crush them.
    if (maxInterest > 0) {
      final barPaint = Paint()
        ..color = AppColors.warning.withValues(alpha: 0.5);
      final slot = plotWidth / points.length;
      final barWidth = slot * 0.42;
      final band = size.height * 0.32;
      for (var i = 0; i < points.length; i++) {
        final interest = interests[i];
        if (interest <= 0) {
          continue;
        }
        final h = band * (interest / maxInterest);
        final cx = xAt(i);
        canvas.drawRect(
          Rect.fromLTWH(cx - barWidth / 2, size.height - h, barWidth, h),
          barPaint,
        );
      }
    }

    // Balance polyline + points.
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xAt(i), balanceY(balances[i]));
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
      } else {
        line.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primaryBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = AppColors.primary;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(xAt(i), balanceY(balances[i])), 3.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.leftPad != leftPad;
  }
}
