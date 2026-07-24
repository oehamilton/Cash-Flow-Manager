import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  group('withRunningBalances', () {
    test('accumulates credits and debits in order', () {
      final txs = [
        _tx(id: 'a', amount: 10000),
        _tx(id: 'b', amount: -2500),
        _tx(id: 'c', amount: 500),
        _tx(id: 'd', amount: -1000),
      ];
      final entries = withRunningBalances(txs);
      expect(entries.map((e) => e.runningBalanceCents).toList(), [
        10000,
        7500,
        8000,
        7000,
      ]);
      expect(entries[0].creditCents, 10000);
      expect(entries[0].debitCents, isNull);
      expect(entries[1].debitCents, 2500);
      expect(entries[1].creditCents, isNull);
    });

    test('handles empty list', () {
      expect(withRunningBalances(const []), isEmpty);
    });
  });

  group('TransactionRepository.listRegisterEntries', () {
    final harness = TempVaultHarness();

    setUp(harness.setUp);
    tearDown(harness.tearDown);

    test('matches account balance and last running balance', () async {
      await harness.createUnlockedVault();
      final accounts = AccountRepository(harness.session);
      final txs = TransactionRepository(harness.session);
      final accountId = accounts.createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 150000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      txs.create(
        TransactionDraft(
          accountId: accountId,
          date: DateTime(2026, 7, 2),
          payee: 'Payroll',
          amountCents: 220000,
        ),
      );
      txs.create(
        TransactionDraft(
          accountId: accountId,
          date: DateTime(2026, 7, 3),
          payee: 'Grocery',
          amountCents: -8450,
        ),
      );

      final entries = txs.listRegisterEntries(accountId);
      expect(entries, hasLength(3));
      expect(entries.first.transaction.isOpeningBalance, isTrue);
      expect(entries.first.runningBalanceCents, 150000);
      expect(entries[1].creditCents, 220000);
      expect(entries[2].debitCents, 8450);
      expect(entries.last.runningBalanceCents, 361550);
      expect(
        entries.last.runningBalanceCents,
        accounts.balanceCents(accountId),
      );
    });
  });
}

Transaction _tx({required String id, required int amount}) {
  final now = DateTime.utc(2026, 7, 1);
  return Transaction(
    id: id,
    accountId: 'acct',
    date: now,
    amountCents: amount,
    isCleared: false,
    source: TransactionSource.manual,
    isUserOverridden: false,
    createdAt: now,
    updatedAt: now,
  );
}
