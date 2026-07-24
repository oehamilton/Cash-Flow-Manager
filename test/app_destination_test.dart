import 'package:cash_flow_manager/app_shell/app_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('destinations expose stable labels in rail order', () {
    expect(AppDestination.values.map((d) => d.label).toList(), [
      'Register',
      'Accounts',
      'Debts',
      'Payees',
      'Settings',
    ]);
  });
}
