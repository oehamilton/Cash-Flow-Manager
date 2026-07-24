import 'dart:math' as math;

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasInterest = points.any((p) => p.interestPaidCents > 0);
    final latest = points.last;

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
                painter: _HistoryChartPainter(points: points),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
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

class _HistoryChartPainter extends CustomPainter {
  _HistoryChartPainter({required this.points});

  final List<AccountMonthPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final balances = points.map((p) => p.balanceCents.toDouble()).toList();
    final interests = points.map((p) => p.interestPaidCents.toDouble()).toList();
    var minY = balances.reduce(math.min);
    var maxY = balances.reduce(math.max);
    final maxInterest = interests.fold<double>(0, math.max);
    if ((maxY - minY).abs() < 1) {
      minY -= 100;
      maxY += 100;
    }
    final pad = (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;

    double xAt(int i) {
      if (points.length == 1) {
        return size.width / 2;
      }
      return size.width * i / (points.length - 1);
    }

    double balanceY(double value) {
      final t = (value - minY) / (maxY - minY);
      return size.height * (1 - t);
    }

    // Zero line when balance range crosses zero.
    if (minY < 0 && maxY > 0) {
      final zeroY = balanceY(0);
      canvas.drawLine(
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = AppColors.outline.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
    }

    // Interest bars use an independent bottom band so debt balances don't crush them.
    if (maxInterest > 0) {
      final barPaint = Paint()
        ..color = AppColors.warning.withValues(alpha: 0.5);
      final slot = size.width / points.length;
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
    return oldDelegate.points != points;
  }
}
