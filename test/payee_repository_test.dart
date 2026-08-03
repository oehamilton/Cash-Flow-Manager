import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/payee.dart';
import 'package:cash_flow_manager/data/payee_repository.dart';
import 'package:cash_flow_manager/data/payee_suggestion.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('create list update delete payees', () async {
    await harness.createUnlockedVault();
    final payees = PayeeRepository(harness.session);
    final id = payees.create(
      const PayeeDraft(name: 'Costco', notes: 'Warehouse', phone: '555'),
    );
    expect(payees.listAll(), hasLength(1));
    expect(payees.getById(id)!.notes, 'Warehouse');

    payees.update(id, const PayeeUpdate(name: 'Costco Wholesale'));
    expect(payees.getById(id)!.name, 'Costco Wholesale');

    payees.delete(id);
    expect(payees.listAll(), isEmpty);
  });

  test('rename updates linked transaction payee text', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final accountId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final payees = PayeeRepository(harness.session);
    final payeeId = payees.create(const PayeeDraft(name: 'Shell'));
    final txs = TransactionRepository(harness.session);
    final txId = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'Shell',
        payeeId: payeeId,
        amountCents: -2500,
      ),
    );
    payees.update(payeeId, const PayeeUpdate(name: 'Shell Oil'));
    expect(txs.getById(txId)!.payee, 'Shell Oil');
  });

  test('merge rewrites payee_id and deletes source', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final accountId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final payees = PayeeRepository(harness.session);
    final a = payees.create(const PayeeDraft(name: 'VISA Typo'));
    final b = payees.create(const PayeeDraft(name: 'Visa'));
    final txs = TransactionRepository(harness.session);
    final txId = txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'VISA Typo',
        payeeId: a,
        amountCents: -1000,
      ),
    );
    payees.merge(sourceId: a, targetId: b);
    expect(payees.getById(a), isNull);
    expect(txs.getById(txId)!.payeeId, b);
    expect(txs.getById(txId)!.payee, 'Visa');
  });

  test('combined suggestions include accounts and managed payees', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final checkingId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    PayeeRepository(harness.session).create(const PayeeDraft(name: 'Amazon'));
    final txs = TransactionRepository(harness.session);
    final suggestions = txs.combinedPayeeSuggestions(checkingId);
    expect(suggestions.whereType<ManagedPayeeSuggestion>(), isNotEmpty);
    expect(
      suggestions.whereType<ManagedPayeeSuggestion>().first.label,
      'Amazon',
    );
  });
}
