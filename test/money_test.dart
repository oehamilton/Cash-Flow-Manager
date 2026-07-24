import 'package:cash_flow_manager/data/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseDollarsToCents handles common formats', () {
    expect(parseDollarsToCents('10'), 1000);
    expect(parseDollarsToCents('10.5'), 1050);
    expect(parseDollarsToCents(r'$1,234.56'), 123456);
    expect(parseDollarsToCents('-20.00'), -2000);
  });

  test('formatCents renders currency', () {
    expect(formatCents(123456), r'$1234.56');
    expect(formatCents(-50), r'-$0.50');
  });
}
