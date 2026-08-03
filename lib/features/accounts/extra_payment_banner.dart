import 'package:flutter/material.dart';

import '../../data/extra_payment_hint.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Banner suggesting an extra payment from primary trough headroom (Phase 4.3).
class ExtraPaymentBanner extends StatelessWidget {
  const ExtraPaymentBanner({
    super.key,
    required this.hint,
  });

  final ExtraPaymentHint hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final target = hint.targetDebt;
    final apr = target?.account.interestRateApr;
    final troughNote =
        '4-week low ${formatCents(hint.trough4WeeksCents)} · today '
        '${formatCents(hint.todayCents)}'
        '${hint.minBalanceCents > 0 ? ' · min ${formatCents(hint.minBalanceCents)}' : ''}';
    final String body;
    if (target == null) {
      body = hint.hasSurplus
          ? 'Suggested extra payment: ${formatCents(hint.surplusCents)} '
              '($troughNote). Add a debt with APR to aim it.'
          : 'No extra payment suggested ($troughNote). '
              '4-week low is at or below your minimum balance.';
    } else if (hint.hasSurplus) {
      final aprText = apr == null ? '' : ' (${apr.toStringAsFixed(2)}% APR)';
      body = 'Suggested extra payment: ${formatCents(hint.surplusCents)} '
          'toward ${target.account.name}$aprText. '
          '($troughNote)';
    } else {
      body = 'No extra payment suggested ($troughNote). '
          'Highest APR debt: ${target.account.name}'
          '${apr == null ? '' : ' at ${apr.toStringAsFixed(2)}%'}.';
    }

    return DecoratedBox(
      key: const Key('extra_payment_banner'),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extra payment hint',
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.primaryBright,
                fontFamily: AppTheme.monoFont,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              key: const Key('extra_payment_banner_body'),
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
