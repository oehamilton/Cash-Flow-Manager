import 'package:cash_flow_manager/data/account_repository.dart';
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

  test('setCleared toggles flag and writes audit', () async {
    final (accountId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'Store',
        amountCents: -2000,
      ),
    );

    expect(txs.clearedBalanceCents(accountId), 10000);
    txs.setCleared(id, cleared: true);
    expect(txs.getById(id)!.isCleared, isTrue);
    expect(txs.clearedBalanceCents(accountId), 8000);

    final audit = AuditLogRepository(harness.session).recent();
    expect(
      audit.any(
        (e) =>
            e['action'] == AuditAction.clear &&
            e['entity_id'] == id &&
            e['category'] == AuditCategory.transaction,
      ),
      isTrue,
    );

    txs.setCleared(id, cleared: false);
    expect(txs.getById(id)!.isCleared, isFalse);
    expect(
      AuditLogRepository(harness.session).recent().any(
            (e) =>
                e['action'] == AuditAction.unclear && e['entity_id'] == id,
          ),
      isTrue,
    );
  });

  test('cleared transactions cannot be updated or deleted', () async {
    final (accountId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'Store',
        amountCents: -2000,
      ),
    );
    txs.setCleared(id, cleared: true);

    expect(
      () => txs.update(id, const TransactionUpdate(amountCents: -1500)),
      throwsA(isA<StateError>()),
    );
    expect(() => txs.delete(id), throwsA(isA<StateError>()));
  });

  test('opening balance cannot be uncleared', () async {
    final (accountId, txs) = await setup();
    final opening = txs.listForAccount(accountId).single;
    expect(
      () => txs.setCleared(opening.id, cleared: false),
      throwsA(isA<StateError>()),
    );
  });

  test('finishReconcile requires matching statement balance', () async {
    final (accountId, txs) = await setup();
    final id = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'Store',
        amountCents: -2000,
      ),
    );
    txs.setCleared(id, cleared: true);

    expect(
      () => txs.finishReconcile(
        accountId: accountId,
        statementEndingBalanceCents: 9999,
      ),
      throwsA(isA<StateError>()),
    );

    txs.finishReconcile(
      accountId: accountId,
      statementEndingBalanceCents: 8000,
    );

    expect(
      AuditLogRepository(harness.session).recent().any(
            (e) =>
                e['action'] == AuditAction.reconcile &&
                e['entity_id'] == accountId,
          ),
      isTrue,
    );
  });
}
