import 'transaction.dart';

/// Lowest projected balance in a forward window, with the date it occurs.
class ForecastTroughResult {
  const ForecastTroughResult({
    required this.cents,
    required this.date,
  });

  final int cents;
  final DateTime date;
}

/// Lowest projected register balance over a forward window (Phase 3.5).
///
/// - **4-week low:** min from today through day 28.
/// - **8-week low:** min from after day 28 through day 56 (weeks 4–8), not
///   the whole 8-week span.
abstract final class ForecastTrough {
  static const weeks4Days = 28;
  static const weeks8Days = 56;

  /// Lowest balance in `(asOf + startAfterDays, asOf + endDays]` (calendar days).
  ///
  /// Seeds with the projected balance at the start of the window (today's
  /// balance when [startAfterDays] is 0; otherwise the last running balance on
  /// or before that boundary), then mins with running balances of later txs
  /// through [endDays]. [ForecastTroughResult.date] is when that low is hit.
  static ForecastTroughResult lowestInWindow({
    required int balanceThroughToday,
    required Iterable<RegisterEntry> entries,
    required DateTime asOf,
    required int startAfterDays,
    required int endDays,
  }) {
    assert(startAfterDays >= 0);
    assert(endDays >= startAfterDays);

    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final start = today.add(Duration(days: startAfterDays));
    final end = today.add(Duration(days: endDays));

    var trough = balanceThroughToday;
    var troughDate = today;
    if (startAfterDays > 0) {
      for (final entry in entries) {
        final d = _dateOnly(entry.transaction.date);
        if (d.isAfter(start)) {
          break;
        }
        if (d.isAfter(today)) {
          trough = entry.runningBalanceCents;
          troughDate = d;
        }
      }
    }

    for (final entry in entries) {
      final d = _dateOnly(entry.transaction.date);
      if (!d.isAfter(start) || d.isAfter(end)) {
        continue;
      }
      if (entry.runningBalanceCents < trough) {
        trough = entry.runningBalanceCents;
        troughDate = d;
      }
    }
    return ForecastTroughResult(cents: trough, date: troughDate);
  }

  /// Convenience: lowest from after today through [horizonDays] (4-week style).
  static ForecastTroughResult lowestInHorizon({
    required int balanceThroughToday,
    required Iterable<RegisterEntry> entries,
    required DateTime asOf,
    required int horizonDays,
  }) {
    return lowestInWindow(
      balanceThroughToday: balanceThroughToday,
      entries: entries,
      asOf: asOf,
      startAfterDays: 0,
      endDays: horizonDays,
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
