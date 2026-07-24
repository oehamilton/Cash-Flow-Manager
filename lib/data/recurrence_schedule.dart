import 'recurrence_frequency.dart';

/// Calendar-date helpers for recurrence schedules (Phase 3.2).
abstract final class RecurrenceSchedule {
  /// Advances [from] by one period for [frequency] / [interval].
  ///
  /// Dates are treated as local calendar dates (time-of-day ignored).
  static DateTime nextOccurrence(
    DateTime from, {
    required RecurrenceFrequency frequency,
    required int interval,
    int? anchorDayOfMonth,
  }) {
    if (interval < 1) {
      throw ArgumentError('Interval must be at least 1');
    }
    final current = dateOnly(from);
    return switch (frequency) {
      RecurrenceFrequency.daily => current.add(Duration(days: interval)),
      RecurrenceFrequency.weekly => current.add(Duration(days: 7 * interval)),
      RecurrenceFrequency.biweekly =>
        current.add(Duration(days: 14 * interval)),
      RecurrenceFrequency.semimonthly => _nextSemimonthly(
          current,
          interval: interval,
          anchorDay: anchorDayOfMonth ?? current.day,
        ),
      RecurrenceFrequency.monthly => addMonths(current, interval),
      RecurrenceFrequency.quarterly => addMonths(current, 3 * interval),
      RecurrenceFrequency.yearly => addMonths(current, 12 * interval),
    };
  }

  /// Occurrences on/after [start] through [end] inclusive, walking from [anchor].
  static List<DateTime> occurrencesInRange({
    required DateTime anchor,
    required DateTime start,
    required DateTime end,
    required RecurrenceFrequency frequency,
    required int interval,
    DateTime? ruleEnd,
  }) {
    final rangeStart = dateOnly(start);
    final rangeEnd = dateOnly(end);
    final hardEnd =
        ruleEnd == null ? rangeEnd : minDate(dateOnly(ruleEnd), rangeEnd);
    if (hardEnd.isBefore(rangeStart)) {
      return const [];
    }

    var cursor = dateOnly(anchor);
    final anchorDay = cursor.day;
    // Fast-forward to the first occurrence on/after rangeStart.
    var guard = 0;
    while (cursor.isBefore(rangeStart)) {
      cursor = nextOccurrence(
        cursor,
        frequency: frequency,
        interval: interval,
        anchorDayOfMonth: anchorDay,
      );
      if (++guard > 100000) {
        throw StateError('Recurrence fast-forward exceeded safety limit');
      }
    }

    final out = <DateTime>[];
    guard = 0;
    while (!cursor.isAfter(hardEnd)) {
      out.add(cursor);
      cursor = nextOccurrence(
        cursor,
        frequency: frequency,
        interval: interval,
        anchorDayOfMonth: anchorDay,
      );
      if (++guard > 100000) {
        throw StateError('Recurrence expand exceeded safety limit');
      }
    }
    return out;
  }

  /// Calendar date from Y/M/D components (avoids UTC midnight TZ shifts).
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Parse a stored `YYYY-MM-DD` value as a local calendar date (not UTC midnight).
  static DateTime parseDateOnly(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
    if (match == null) {
      return dateOnly(DateTime.parse(trimmed));
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static String formatDate(DateTime date) {
    final d = dateOnly(date);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime addMonths(DateTime date, int months) {
    final d = dateOnly(date);
    final totalMonths = d.year * 12 + (d.month - 1) + months;
    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final day = d.day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static DateTime minDate(DateTime a, DateTime b) =>
      a.isBefore(b) ? a : b;

  /// Semimonthly: alternate between [anchorDay] and mid-month companion day.
  static DateTime _nextSemimonthly(
    DateTime current, {
    required int interval,
    required int anchorDay,
  }) {
    var cursor = current;
    for (var i = 0; i < interval; i++) {
      final dayA = anchorDay.clamp(1, 28);
      final dayB = (dayA <= 15 ? dayA + 15 : dayA - 15).clamp(1, 28);
      final first = dayA < dayB ? dayA : dayB;
      final second = dayA < dayB ? dayB : dayA;

      if (cursor.day < second) {
        final target = cursor.day < first ? first : second;
        cursor = DateTime(
          cursor.year,
          cursor.month,
          target.clamp(1, _daysInMonth(cursor.year, cursor.month)),
        );
      } else {
        final nextMonth = addMonths(
          DateTime(cursor.year, cursor.month, 1),
          1,
        );
        cursor = DateTime(
          nextMonth.year,
          nextMonth.month,
          first.clamp(1, _daysInMonth(nextMonth.year, nextMonth.month)),
        );
      }
    }
    return cursor;
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
