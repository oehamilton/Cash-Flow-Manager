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

/// Pair of register forecast lows (today→4 weeks, and weeks 4–8).
class ForecastTroughPair {
  const ForecastTroughPair({
    required this.weeks4,
    required this.weeks4to8,
  });

  final ForecastTroughResult weeks4;
  final ForecastTroughResult weeks4to8;
}

/// Lowest projected register balance over a forward window (Phase 3.5).
///
/// - **4-week low:** min from today through day 28.
/// - **8-week low:** min from after day 28 through day 56 (weeks 4–8), not
///   the whole 8-week span.
abstract final class ForecastTrough {
  static const weeks4Days = 28;
  static const weeks8Days = 56;

  /// Both trough chips from one chronological scan (register is date-ordered).
  static ForecastTroughPair pairForRegister({
    required int balanceThroughToday,
    required Iterable<RegisterEntry> entries,
    required DateTime asOf,
  }) {
    final today = _dateOnly(asOf);
    final day28 = _addDays(today, weeks4Days);
    final day56 = _addDays(today, weeks8Days);

    var trough4 = balanceThroughToday;
    var trough4Date = today;
    // Seed weeks 4–8 with balance at the week-4 boundary (last running on/before
    // day 28, else today's balance).
    var trough8 = balanceThroughToday;
    var trough8Date = today;

    for (final entry in entries) {
      final d = _dateOnly(entry.transaction.date);
      if (!d.isAfter(today)) {
        continue;
      }
      if (d.isAfter(day56)) {
        break;
      }

      final bal = entry.runningBalanceCents;
      if (!d.isAfter(day28)) {
        if (bal < trough4) {
          trough4 = bal;
          trough4Date = d;
        }
        trough8 = bal;
        trough8Date = d;
      } else if (bal < trough8) {
        trough8 = bal;
        trough8Date = d;
      }
    }

    return ForecastTroughPair(
      weeks4: ForecastTroughResult(cents: trough4, date: trough4Date),
      weeks4to8: ForecastTroughResult(cents: trough8, date: trough8Date),
    );
  }

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

    final today = _dateOnly(asOf);
    final start = _addDays(today, startAfterDays);
    final end = _addDays(today, endDays);

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

  /// Calendar-day arithmetic (avoids DST shifting midnight via [Duration]).
  static DateTime _addDays(DateTime date, int days) {
    final base = _dateOnly(date);
    return DateTime(base.year, base.month, base.day + days);
  }
}
