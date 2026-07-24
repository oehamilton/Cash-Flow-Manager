import 'package:cash_flow_manager/data/sql_escape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escapeSqlString doubles single quotes', () {
    expect(escapeSqlString("o'reilly"), "o''reilly");
    expect(escapeSqlString('plain'), 'plain');
  });
}
