import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<(String checkingId, String cardId, TransactionRepository txs)>
      setup() async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final checkingId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 100000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final cardId = accounts.create(
      AccountDraft(
        name: 'Visa',
        type: AccountType.creditCard,
        openingBalanceCents: 50000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    return (checkingId, cardId, TransactionRepository(harness.session));
  }

  test('create transfer writes paired legs with debt payment signs', () async {
    final (checkingId, cardId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: checkingId,
        date: DateTime(2026, 7, 10),
        transferToAccountId: cardId,
        amountCents: -20000,
      ),
    );

    final source = txs.getById(id)!;
    final dest = txs.transferCounterpart(id)!;
    expect(source.transferPairId, isNotNull);
    expect(dest.transferPairId, source.transferPairId);
    expect(source.accountId, checkingId);
    expect(dest.accountId, cardId);
    expect(source.amountCents, -20000);
    expect(dest.amountCents, -20000);
    expect(source.payee, 'Visa');
    expect(dest.payee, 'Checking');
  });

  test('create asset-to-asset transfer uses opposite signs', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final checkingId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 100000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final savingsId = accounts.create(
      AccountDraft(
        name: 'Savings',
        type: AccountType.savings,
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final txs = TransactionRepository(harness.session);
    final id = txs.create(
      TransactionDraft(
        accountId: checkingId,
        date: DateTime(2026, 7, 11),
        transferToAccountId: savingsId,
        amountCents: -5000,
      ),
    );
    final dest = txs.transferCounterpart(id)!;
    expect(dest.amountCents, 5000);
  });

  test('delete removes both transfer legs', () async {
    final (checkingId, cardId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: checkingId,
        date: DateTime(2026, 7, 10),
        transferToAccountId: cardId,
        amountCents: -10000,
      ),
    );
    final pairId = txs.getById(id)!.transferPairId!;
    txs.delete(id);
    expect(txs.getById(id), isNull);
    final leftover = harness.session.database.select(
      'SELECT id FROM transactions WHERE transfer_pair_id = ?',
      [pairId],
    );
    expect(leftover, isEmpty);
  });

  test('update amount syncs counterpart', () async {
    final (checkingId, cardId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: checkingId,
        date: DateTime(2026, 7, 10),
        transferToAccountId: cardId,
        amountCents: -10000,
      ),
    );
    txs.update(
      id,
      const TransactionUpdate(amountCents: -15000),
    );
    final dest = txs.transferCounterpart(id)!;
    expect(txs.getById(id)!.amountCents, -15000);
    expect(dest.amountCents, -15000);
  });

  test('clear one leg does not clear the other', () async {
    final (checkingId, cardId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: checkingId,
        date: DateTime(2026, 7, 10),
        transferToAccountId: cardId,
        amountCents: -10000,
      ),
    );
    final dest = txs.transferCounterpart(id)!;
    txs.setCleared(id, cleared: true);
    expect(txs.getById(id)!.isCleared, isTrue);
    expect(txs.getById(dest.id)!.isCleared, isFalse);
  });

  test('cannot transfer to self', () async {
    final (checkingId, _, txs) = await setup();
    expect(
      () => txs.create(
        TransactionDraft(
          accountId: checkingId,
          date: DateTime(2026, 7, 10),
          transferToAccountId: checkingId,
          amountCents: -1000,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('unlinking deletes counterpart', () async {
    final (checkingId, cardId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: checkingId,
        date: DateTime(2026, 7, 10),
        transferToAccountId: cardId,
        amountCents: -10000,
      ),
    );
    final destId = txs.transferCounterpart(id)!.id;
    txs.update(
      id,
      const TransactionUpdate(
        payee: 'Grocery',
        clearTransfer: true,
      ),
    );
    expect(txs.getById(id)!.transferPairId, isNull);
    expect(txs.getById(id)!.payee, 'Grocery');
    expect(txs.getById(destId), isNull);
  });
}
