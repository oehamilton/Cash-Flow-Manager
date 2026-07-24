import 'package:flutter/material.dart';

import '../../data/transaction.dart';
import '../../theme/app_colors.dart';

/// Visual treatment for a register row (Phase 3.3 forecast visuals).
///
/// Distinct bands: cleared | uncleared past | auto future | manual future.
class RegisterRowStyle {
  const RegisterRowStyle({
    required this.background,
    required this.accent,
    required this.mutedForeground,
    required this.kind,
  });

  final Color background;
  final Color accent;
  final bool mutedForeground;
  final RegisterRowKind kind;

  static RegisterRowStyle forTransaction(
    Transaction tx, {
    DateTime? asOf,
  }) {
    if (tx.isCleared) {
      return const RegisterRowStyle(
        background: AppColors.rowCleared,
        accent: AppColors.primary,
        mutedForeground: true,
        kind: RegisterRowKind.cleared,
      );
    }

    final today = asOf ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    if (txDate.isAfter(todayDate)) {
      final isManualFuture = TransactionSource.isUserManual(tx.source);
      if (isManualFuture) {
        return const RegisterRowStyle(
          background: AppColors.rowManualFuture,
          accent: AppColors.warning,
          mutedForeground: false,
          kind: RegisterRowKind.manualFuture,
        );
      }
      return const RegisterRowStyle(
        background: AppColors.rowAutoFuture,
        accent: AppColors.primaryBright,
        mutedForeground: false,
        kind: RegisterRowKind.autoFuture,
      );
    }

    return const RegisterRowStyle(
      background: AppColors.rowUnclearedPast,
      accent: AppColors.danger,
      mutedForeground: false,
      kind: RegisterRowKind.unclearedPast,
    );
  }
}

/// Register row visual categories for legend / tests (Phase 3.3).
enum RegisterRowKind {
  cleared,
  unclearedPast,
  autoFuture,
  manualFuture,
}
