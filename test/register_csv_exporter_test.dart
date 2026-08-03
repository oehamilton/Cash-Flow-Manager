import 'package:cash_flow_manager/data/register_csv_exporter.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggestedFileName sanitizes account name', () {
    expect(
      RegisterCsvExporter.suggestedFileName(
        'Primary Checking!',
        asOf: DateTime(2026, 7, 24),
      ),
      'Primary_Checking-register-20260724.csv',
    );
  });

  test('export uses dollar decimals and escapes commas/quotes', () {
    final now = DateTime.utc(2026, 7, 1);
    final csv = RegisterCsvExporter.export([
      RegisterEntry(
        transaction: Transaction(
          id: 'tx-1',
          accountId: 'a1',
          date: DateTime(2026, 7, 15),
          payee: 'Store, "Main"',
          memo: 'note',
          amountCents: -4525,
          isCleared: true,
          source: TransactionSource.manual,
          isUserOverridden: false,
          interestCents: 125,
          principalCents: 4400,
          createdAt: now,
          updatedAt: now,
        ),
        runningBalanceCents: 5475,
      ),
    ]);

    expect(
      csv.split('\n').first,
      'date,payee,memo,amount,debit,credit,'
      'running_balance,cleared,source,interest,principal,id',
    );
    expect(csv, contains('2026-07-15'));
    expect(csv, contains('"Store, ""Main"""'));
    expect(csv, contains(',-45.25,45.25,,54.75,1,manual,1.25,44.00,tx-1'));
  });
}
