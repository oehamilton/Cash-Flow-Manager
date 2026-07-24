import 'package:flutter/material.dart';

import '../../data/transaction.dart';
import '../../theme/app_colors.dart';

/// Visual treatment for a register row (Phase 2.5).
///
/// Forecast-specific colors (auto/manual future) arrive in Phase 3.3; until
/// then future-dated uncleared rows share the uncleared-past treatment.
class RegisterRowStyle {
  const RegisterRowStyle({
    required this.background,
    required this.accent,
    required this.mutedForeground,
  });

  final Color background;
  final Color accent;
  final bool mutedForeground;

  static RegisterRowStyle forTransaction(
    Transaction tx, {
    DateTime? asOf,
  }) {
    if (tx.isCleared) {
      return const RegisterRowStyle(
        background: AppColors.rowCleared,
        accent: AppColors.primary,
        mutedForeground: true,
      );
    }

    final today = asOf ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    if (txDate.isAfter(todayDate)) {
      // Preview of Phase 3.3: slight distinction for future-dated manuals.
      final isManualFuture = tx.source == TransactionSource.manualFuture ||
          tx.source == TransactionSource.manual;
      return RegisterRowStyle(
        background: isManualFuture
            ? AppColors.rowManualFuture
            : AppColors.rowAutoFuture,
        accent: AppColors.warning,
        mutedForeground: false,
      );
    }

    return const RegisterRowStyle(
      background: AppColors.rowUnclearedPast,
      accent: AppColors.danger,
      mutedForeground: false,
    );
  }
}
