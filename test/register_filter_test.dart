import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/features/register/register_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RegisterEntry entry({
    required String payee,
    String? memo,
    required bool cleared,
    required DateTime date,
    int running = 0,
  }) {
    final now = DateTime.utc(2026, 7, 1);
    return RegisterEntry(
      transaction: Transaction(
        id: payee,
        accountId: 'a',
        date: date,
        payee: payee,
        memo: memo,
        amountCents: -100,
        isCleared: cleared,
        source: TransactionSource.manual,
        isUserOverridden: false,
        createdAt: now,
        updatedAt: now,
      ),
      runningBalanceCents: running,
    );
  }

  final rows = [
    entry(
      payee: 'Payroll',
      cleared: true,
      date: DateTime(2026, 7, 1),
      running: 100,
    ),
    entry(
      payee: 'Grocery Market',
      memo: 'Weekly shop',
      cleared: false,
      date: DateTime(2026, 7, 5),
      running: 50,
    ),
    entry(
      payee: 'Electric Co',
      cleared: false,
      date: DateTime(2026, 7, 10),
      running: 20,
    ),
  ];

  test('query matches payee or memo', () {
    final byPayee = applyRegisterFilter(
      rows,
      const RegisterFilter(query: 'grocery'),
    );
    expect(byPayee, hasLength(1));
    expect(byPayee.single.transaction.payee, 'Grocery Market');
    // Running balance preserved from full register.
    expect(byPayee.single.runningBalanceCents, 50);

    final byMemo = applyRegisterFilter(
      rows,
      const RegisterFilter(query: 'weekly'),
    );
    expect(byMemo.single.transaction.payee, 'Grocery Market');
  });

  test('cleared facet filters', () {
    final cleared = applyRegisterFilter(
      rows,
      const RegisterFilter(cleared: ClearedFilter.cleared),
    );
    expect(cleared.map((e) => e.transaction.payee), ['Payroll']);

    final open = applyRegisterFilter(
      rows,
      const RegisterFilter(cleared: ClearedFilter.uncleared),
    );
    expect(open, hasLength(2));
  });

  test('date bounds filter inclusive calendar days', () {
    final filtered = applyRegisterFilter(
      rows,
      RegisterFilter(
        dateFrom: DateTime(2026, 7, 5),
        dateTo: DateTime(2026, 7, 5),
      ),
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.transaction.payee, 'Grocery Market');
  });

  test('inactive filter returns all rows', () {
    expect(applyRegisterFilter(rows, const RegisterFilter()), hasLength(3));
  });
}
