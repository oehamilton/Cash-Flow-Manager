import 'account_type.dart';

/// Sign rules for linked transfer legs (Phase 6.1).
///
/// Exactly one debt ↔ asset: same signed amount (payment/advance).
/// Otherwise (asset↔asset, income↔asset, …): opposite signs.
abstract final class TransferAmounts {
  /// Counterpart amount for the destination register given the source amount.
  static int counterpartAmount({
    required AccountType sourceType,
    required AccountType destType,
    required int sourceAmountCents,
  }) {
    if (sourceType.isDebt ^ destType.isDebt) {
      return sourceAmountCents;
    }
    return -sourceAmountCents;
  }
}
