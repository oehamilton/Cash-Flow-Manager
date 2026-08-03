import 'package:cash_flow_manager/features/register/register_date_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asOf = DateTime(2026, 8, 5); // Wednesday

  test('parses ISO day and US slash day', () {
    final iso = RegisterDateQuery.tryParse('2026-08-03', asOf: asOf)!;
    expect(iso.matches(DateTime(2026, 8, 3)), isTrue);
    expect(iso.matches(DateTime(2026, 8, 4)), isFalse);

    final us = RegisterDateQuery.tryParse('8/3/2026', asOf: asOf)!;
    expect(us.matches(DateTime(2026, 8, 3)), isTrue);
  });

  test('parses month as YYYY-MM and month name', () {
    final ym = RegisterDateQuery.tryParse('2026-08', asOf: asOf)!;
    expect(ym.matches(DateTime(2026, 8, 1)), isTrue);
    expect(ym.matches(DateTime(2026, 8, 31)), isTrue);
    expect(ym.matches(DateTime(2026, 7, 31)), isFalse);

    final named = RegisterDateQuery.tryParse('Aug 2026', asOf: asOf)!;
    expect(named.matches(DateTime(2026, 8, 15)), isTrue);
  });

  test('parses this week / this month relative to asOf', () {
    // Sunday 2026-08-02 .. Saturday 2026-08-08
    final week = RegisterDateQuery.tryParse('this week', asOf: asOf)!;
    expect(week.matches(DateTime(2026, 8, 2)), isTrue);
    expect(week.matches(DateTime(2026, 8, 8)), isTrue);
    expect(week.matches(DateTime(2026, 8, 1)), isFalse);

    final month = RegisterDateQuery.tryParse('this month', asOf: asOf)!;
    expect(month.matches(DateTime(2026, 8, 1)), isTrue);
    expect(month.matches(DateTime(2026, 9, 1)), isFalse);
  });

  test('parses week of and ISO week', () {
    final weekOf = RegisterDateQuery.tryParse('week of 8/5/2026', asOf: asOf)!;
    expect(weekOf.matches(DateTime(2026, 8, 2)), isTrue);
    expect(weekOf.matches(DateTime(2026, 8, 9)), isFalse);

    // 2026-W32: Mon 2026-08-03 .. Sun 2026-08-09
    final iso = RegisterDateQuery.tryParse('2026-W32', asOf: asOf)!;
    expect(iso.matches(DateTime(2026, 8, 3)), isTrue);
    expect(iso.matches(DateTime(2026, 8, 9)), isTrue);
    expect(iso.matches(DateTime(2026, 8, 2)), isFalse);
  });

  test('non-date text returns null', () {
    expect(RegisterDateQuery.tryParse('grocery', asOf: asOf), isNull);
    expect(RegisterDateQuery.tryParse('aug', asOf: asOf), isNull);
  });
}
