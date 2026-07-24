import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/audit_categories.dart';
import 'package:cash_flow_manager/data/audit_log_repository.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<(String accountId, TransactionRepository txs)> setup() async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final accountId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    return (accountId, TransactionRepository(harness.session));
  }

  test('create/list/update/delete with audit writes', () async {
    final (accountId, txs) = await setup();

    final id = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 10),
        payee: 'Grocery Market',
        memo: 'Weekly shop',
        amountCents: -4525,
      ),
    );

    final listed = txs.listForAccount(accountId);
    expect(listed, hasLength(2)); // opening + new
    expect(listed.last.id, id);
    expect(listed.last.payee, 'Grocery Market');
    expect(listed.last.amountCents, -4525);
    expect(listed.last.source, TransactionSource.manual);
    expect(listed.last.isCleared, isFalse);

    txs.update(
      id,
      const TransactionUpdate(
        payee: 'Grocery Market West',
        amountCents: -5000,
      ),
    );
    expect(txs.getById(id)!.payee, 'Grocery Market West');
    expect(txs.getById(id)!.amountCents, -5000);

    final audit = AuditLogRepository(harness.session).recent();
    expect(
      audit.any(
        (e) =>
            e['category'] == AuditCategory.transaction &&
            e['action'] == AuditAction.create &&
            e['entity_id'] == id,
      ),
      isTrue,
    );
    expect(
      audit.any(
        (e) =>
            e['category'] == AuditCategory.transaction &&
            e['action'] == AuditAction.update &&
            e['entity_id'] == id,
      ),
      isTrue,
    );

    txs.delete(id);
    expect(txs.listForAccount(accountId), hasLength(1));
    expect(
      AuditLogRepository(harness.session).recent().any(
            (e) =>
                e['category'] == AuditCategory.transaction &&
                e['action'] == AuditAction.delete &&
                e['entity_id'] == id,
          ),
      isTrue,
    );
  });

  test('payeeSuggestions returns distinct history with prefix filter', () async {
    final (accountId, txs) = await setup();
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 2),
        payee: 'Payroll',
        amountCents: 200000,
      ),
    );
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 3),
        payee: 'Payroll Overtime',
        amountCents: 15000,
      ),
    );
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 4),
        payee: 'Electric Co',
        amountCents: -9000,
      ),
    );

    final all = txs.payeeSuggestions(accountId);
    expect(all, containsAll(['Electric Co', 'Payroll', 'Payroll Overtime']));
    // Opening Balance is also a distinct payee.
    expect(all, contains('Opening Balance'));

    final prefix = txs.payeeSuggestions(accountId, prefix: 'pay');
    expect(prefix, containsAll(['Payroll', 'Payroll Overtime']));
    expect(prefix, isNot(contains('Electric Co')));
  });

  test('opening balance cannot be updated or deleted', () async {
    final (accountId, txs) = await setup();
    final opening = txs.listForAccount(accountId).single;
    expect(opening.isOpeningBalance, isTrue);

    expect(
      () => txs.update(
        opening.id,
        const TransactionUpdate(amountCents: 1),
      ),
      throwsA(isA<StateError>()),
    );
    expect(() => txs.delete(opening.id), throwsA(isA<StateError>()));
    expect(txs.listForAccount(accountId), hasLength(1));
  });

  test('balance reflects created and deleted transactions', () async {
    final (accountId, txs) = await setup();
    final accounts = AccountRepository(harness.session);
    expect(accounts.balanceCents(accountId), 10000);

    final id = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'Transfer',
        amountCents: -2500,
      ),
    );
    expect(accounts.balanceCents(accountId), 7500);

    txs.delete(id);
    expect(accounts.balanceCents(accountId), 10000);
  });

  test('listForAccount does not leak transactions across accounts', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final txs = TransactionRepository(harness.session);

    final primaryId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Primary Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final cardId = accounts.create(
      AccountDraft(
        name: 'Travel Card',
        type: AccountType.creditCard,
        openingBalanceCents: 20000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    final txId = txs.create(
      TransactionDraft(
        accountId: primaryId,
        date: DateTime(2026, 7, 10),
        payee: 'Unique Payee XYZ',
        amountCents: -1234,
      ),
    );

    final primaryList = txs.listForAccount(primaryId);
    final cardList = txs.listForAccount(cardId);

    expect(primaryList.any((t) => t.id == txId), isTrue);
    expect(cardList.any((t) => t.id == txId), isFalse);
    expect(cardList.any((t) => t.payee == 'Unique Payee XYZ'), isFalse);
    expect(cardList, hasLength(1));
    expect(cardList.single.isOpeningBalance, isTrue);
  });

  test('future-dated create uses manual_future; moving date retags source',
      () async {
    final (accountId, txs) = await setup();
    final asOf = DateTime(2026, 7, 15);

    final futureId = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 8, 1),
        payee: 'Planned purchase',
        amountCents: -5000,
      ),
      asOf: asOf,
    );
    expect(txs.getById(futureId)!.source, TransactionSource.manualFuture);

    txs.update(
      futureId,
      TransactionUpdate(date: DateTime(2026, 7, 10)),
      asOf: asOf,
    );
    expect(txs.getById(futureId)!.source, TransactionSource.manual);

    txs.update(
      futureId,
      TransactionUpdate(date: DateTime(2026, 9, 1)),
      asOf: asOf,
    );
    expect(txs.getById(futureId)!.source, TransactionSource.manualFuture);
  });
}
