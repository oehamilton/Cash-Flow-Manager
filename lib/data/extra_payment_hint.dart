import 'account.dart';
import 'transaction.dart';

/// Suggests an avalanche-style extra payment from primary trough headroom (4.3).
class ExtraPaymentHint {
  const ExtraPaymentHint({
    required this.todayCents,
    required this.trough4WeeksCents,
    required this.surplusCents,
    required this.minBalanceCents,
    this.targetDebt,
  });

  final int todayCents;
  final int trough4WeeksCents;

  /// Soft floor reserved on the primary checking register.
  final int minBalanceCents;

  /// Suggested extra payment: `max(0, 4-week trough − min balance)`.
  ///
  /// Amount you can put toward debt and still clear the 4-week low at/above
  /// your minimum balance.
  final int surplusCents;
  final AccountSummary? targetDebt;

  bool get hasSurplus => surplusCents > 0;

  /// Debts sorted highest APR first (null APR last), then highest balance owed.
  ///
  /// Debt registers use positive balance = amount owed (negative = credit).
  static List<AccountSummary> sortByAprDesc(Iterable<AccountSummary> debts) {
    final list = debts.toList();
    list.sort((a, b) {
      final aprA = a.account.interestRateApr;
      final aprB = b.account.interestRateApr;
      if (aprA == null && aprB == null) {
        return b.balanceCents.compareTo(a.balanceCents);
      }
      if (aprA == null) {
        return 1;
      }
      if (aprB == null) {
        return -1;
      }
      final byApr = aprB.compareTo(aprA);
      if (byApr != 0) {
        return byApr;
      }
      return b.balanceCents.compareTo(a.balanceCents);
    });
    return list;
  }

  /// Highest-APR debt that still has a positive (owed) balance.
  static AccountSummary? highestAprTarget(Iterable<AccountSummary> debts) {
    for (final row in sortByAprDesc(debts)) {
      if (row.balanceCents > 0) {
        return row;
      }
    }
    return null;
  }

  static ExtraPaymentHint? fromPrimary({
    required RegisterMetrics primaryMetrics,
    required List<AccountSummary> debts,
    int minBalanceCents = 0,
  }) {
    final trough = primaryMetrics.trough4WeeksCents;
    if (trough == null) {
      return null;
    }
    final buffer = minBalanceCents < 0 ? 0 : minBalanceCents;
    final surplus = trough - buffer;
    return ExtraPaymentHint(
      todayCents: primaryMetrics.todayCents,
      trough4WeeksCents: trough,
      minBalanceCents: buffer,
      surplusCents: surplus > 0 ? surplus : 0,
      targetDebt: highestAprTarget(debts),
    );
  }
}
