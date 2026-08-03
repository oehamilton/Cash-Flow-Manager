/// Parses register search text into an optional calendar match (day / week / month).
///
/// Supported examples: `2026-08-03`, `8/3/2026`, `2026-08`, `Aug 2026`,
/// `2026-W31`, `week of 8/3/2026`, `today`, `this week`, `this month`, `last month`.
class RegisterDateQuery {
  const RegisterDateQuery._({
    required this.from,
    required this.to,
  });

  /// Inclusive calendar-day bounds (local dates, time stripped).
  final DateTime from;
  final DateTime to;

  bool matches(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  /// Returns a date query when [raw] is primarily a date/week/month token.
  ///
  /// Returns null when the text should be treated as payee/memo search only.
  static RegisterDateQuery? tryParse(String raw, {DateTime? asOf}) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    final now = asOf ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (text) {
      case 'today':
        return RegisterDateQuery._(from: today, to: today);
      case 'yesterday':
        final y = today.subtract(const Duration(days: 1));
        return RegisterDateQuery._(from: y, to: y);
      case 'this week':
        return _weekContaining(today, sundayStart: true);
      case 'last week':
        return _weekContaining(
          today.subtract(const Duration(days: 7)),
          sundayStart: true,
        );
      case 'this month':
        return _month(today.year, today.month);
      case 'last month':
        final firstThis = DateTime(today.year, today.month, 1);
        final lastPrev = firstThis.subtract(const Duration(days: 1));
        return _month(lastPrev.year, lastPrev.month);
    }

    final weekOf = RegExp(
      r'^week\s+of\s+(.+)$',
    ).firstMatch(text);
    if (weekOf != null) {
      final day = _parseDay(weekOf.group(1)!);
      if (day != null) {
        return _weekContaining(day, sundayStart: true);
      }
    }

    final isoWeek = RegExp(r'^(\d{4})-w(\d{1,2})$').firstMatch(text);
    if (isoWeek != null) {
      final year = int.parse(isoWeek.group(1)!);
      final week = int.parse(isoWeek.group(2)!);
      if (week >= 1 && week <= 53) {
        return _isoWeek(year, week);
      }
    }

    final monthName = RegExp(
      r'^(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      r'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|'
      r'nov(?:ember)?|dec(?:ember)?)\s+(\d{4})$',
    ).firstMatch(text);
    if (monthName != null) {
      final month = _monthFromName(monthName.group(1)!);
      final year = int.parse(monthName.group(2)!);
      if (month != null) {
        return _month(year, month);
      }
    }

    final yyyyMm = RegExp(r'^(\d{4})[-/](\d{1,2})$').firstMatch(text);
    if (yyyyMm != null) {
      final year = int.parse(yyyyMm.group(1)!);
      final month = int.parse(yyyyMm.group(2)!);
      if (month >= 1 && month <= 12) {
        return _month(year, month);
      }
    }

    final day = _parseDay(text);
    if (day != null) {
      return RegisterDateQuery._(from: day, to: day);
    }

    return null;
  }

  static RegisterDateQuery _month(int year, int month) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0);
    return RegisterDateQuery._(from: from, to: to);
  }

  /// US-style week: Sunday through Saturday.
  static RegisterDateQuery _weekContaining(
    DateTime day, {
    required bool sundayStart,
  }) {
    final d = _dateOnly(day);
    if (sundayStart) {
      final from = _addDays(d, -(d.weekday % 7));
      return RegisterDateQuery._(from: from, to: _addDays(from, 6));
    }
    final from = _addDays(d, -(d.weekday - 1));
    return RegisterDateQuery._(from: from, to: _addDays(from, 6));
  }

  /// ISO week: Monday start (week 1 contains Jan 4).
  static RegisterDateQuery _isoWeek(int year, int week) {
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = _addDays(jan4, -(jan4.weekday - 1));
    final from = _addDays(week1Monday, (week - 1) * 7);
    return RegisterDateQuery._(from: from, to: _addDays(from, 6));
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Calendar-day arithmetic (avoids DST shifting midnight to 01:00).
  static DateTime _addDays(DateTime date, int days) {
    final base = _dateOnly(date);
    return DateTime(base.year, base.month, base.day + days);
  }

  static DateTime? _parseDay(String text) {
    final iso = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(text);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$').firstMatch(text);
    if (us != null) {
      var year = int.parse(us.group(3)!);
      if (year < 100) {
        year += 2000;
      }
      return _safeDate(
        year,
        int.parse(us.group(1)!),
        int.parse(us.group(2)!),
      );
    }
    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static int? _monthFromName(String name) {
    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[name];
  }
}
