import 'transaction.dart';

/// Lowest projected register balance over a forward horizon (Phase 3.5).
abstract final class ForecastTrough {
  static const weeks4Days = 28;
  static const weeks8Days = 56;

  /// Minimum of [balanceThroughToday] and running balances after each
  /// transaction dated after [asOf] through [asOf] + [horizonDays] (inclusive).
  static int lowestInHorizon({
    required int balanceThroughToday,
    required Iterable<RegisterEntry> entries,
    required DateTime asOf,
    required int horizonDays,
  }) {
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final end = today.add(Duration(days: horizonDays));
    var trough = balanceThroughToday;
    for (final entry in entries) {
      final tx = entry.transaction;
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!d.isAfter(today) || d.isAfter(end)) {
        continue;
      }
      if (entry.runningBalanceCents < trough) {
        trough = entry.runningBalanceCents;
      }
    }
    return trough;
  }
}
