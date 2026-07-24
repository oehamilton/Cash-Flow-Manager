/// One month in a trailing 12-month account history series (Phase 4.2).
class AccountMonthPoint {
  const AccountMonthPoint({
    required this.monthStart,
    required this.balanceCents,
    required this.interestPaidCents,
  });

  /// First calendar day of the month.
  final DateTime monthStart;
  final int balanceCents;

  /// Sum of tagged [interest_cents] for txs dated in this month.
  final int interestPaidCents;

  String get monthKey {
    final y = monthStart.year.toString().padLeft(4, '0');
    final m = monthStart.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  String get shortLabel {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[monthStart.month - 1];
  }
}

/// Pure builders for trailing monthly history (testable without DB).
abstract final class AccountHistory {
  static const months = 12;

  /// First-of-month dates for the trailing [months] ending at [asOf]'s month.
  static List<DateTime> trailingMonthStarts(DateTime asOf) {
    final endMonth = DateTime(asOf.year, asOf.month, 1);
    return [
      for (var i = months - 1; i >= 0; i--)
        DateTime(endMonth.year, endMonth.month - i, 1),
    ];
  }

  /// Last day of [monthStart]'s month, capped at [asOf] when in the current month.
  static DateTime monthEndCap(DateTime monthStart, DateTime asOf) {
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    final asOfDay = DateTime(asOf.year, asOf.month, asOf.day);
    if (lastDay.isAfter(asOfDay)) {
      return asOfDay;
    }
    return lastDay;
  }
}
