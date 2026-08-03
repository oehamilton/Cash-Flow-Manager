import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/audit_categories.dart';
import 'package:cash_flow_manager/data/audit_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<AccountRepository> repo() async {
    await harness.createUnlockedVault();
    return AccountRepository(harness.session);
  }

  test('createPrimaryChecking inserts account and opening balance tx', () async {
    final accounts = await repo();
    expect(accounts.hasPrimaryAccount(), isFalse);

    final id = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Main Checking',
        institution: 'Test Bank',
        openingBalanceCents: 25000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    expect(accounts.hasPrimaryAccount(), isTrue);
    expect(accounts.primaryAccountId(), id);

    final account = accounts.getById(id)!;
    expect(account.name, 'Main Checking');
    expect(account.type, AccountType.checking);
    expect(account.isPrimary, isTrue);
    expect(account.openingBalanceCents, 25000);

    final txs = harness.session.database.select(
      'SELECT payee, amount_cents, source, is_cleared FROM transactions',
    );
    expect(txs, hasLength(1));
    expect(txs.first['payee'], 'Opening Balance');
    expect(txs.first['amount_cents'], 25000);
    expect(txs.first['source'], 'opening_balance');
    expect(txs.first['is_cleared'], 1);

    final audit = AuditLogRepository(harness.session).recent();
    expect(
      audit.any(
        (e) =>
            e['action'] == AuditAction.create &&
            e['entity_id'] == id &&
            e['category'] == AuditCategory.account,
      ),
      isTrue,
    );
  });

  test('create supports non-primary types and debt-list default', () async {
    final accounts = await repo();
    accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    final cardId = accounts.create(
      AccountDraft(
        name: 'Travel Card',
        type: AccountType.creditCard,
        interestRateApr: 19.99,
        minimumPaymentCents: 3500,
        paymentDueDay: 15,
        openingBalanceCents: 50000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    final card = accounts.getById(cardId)!;
    expect(card.type, AccountType.creditCard);
    expect(card.isPrimary, isFalse);
    expect(card.includeInDebtList, isTrue);
    expect(card.interestRateApr, 19.99);
    expect(accounts.listAccounts(), hasLength(2));
  });

  test('checking min_balance_cents persists on create and update', () async {
    final accounts = await repo();
    final id = accounts.create(
      AccountDraft(
        name: 'Buffer Checking',
        type: AccountType.checking,
        isPrimary: true,
        minBalanceCents: 50000,
        openingBalanceCents: 200000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    expect(accounts.getById(id)!.minBalanceCents, 50000);

    accounts.update(id, const AccountUpdate(minBalanceCents: 100000));
    expect(accounts.getById(id)!.minBalanceCents, 100000);

    accounts.update(id, const AccountUpdate(minBalanceCents: 0));
    expect(accounts.getById(id)!.minBalanceCents, 0);
  });

  test('setPrimary transfers primary flag to another checking', () async {
    final accounts = await repo();
    final first = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'First',
        openingBalanceCents: 1,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final second = accounts.create(
      AccountDraft(
        name: 'Second',
        type: AccountType.checking,
        openingBalanceCents: 2,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    accounts.setPrimary(second);
    expect(accounts.primaryAccountId(), second);
    expect(accounts.getById(first)!.isPrimary, isFalse);
    expect(accounts.getById(second)!.isPrimary, isTrue);
  });

  test('cannot set non-checking or archive/delete primary', () async {
    final accounts = await repo();
    final primary = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Primary',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final savings = accounts.create(
      AccountDraft(
        name: 'Savings',
        type: AccountType.savings,
        openingBalanceCents: 100,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    expect(
      () => accounts.setPrimary(savings),
      throwsA(isA<ArgumentError>()),
    );
    expect(() => accounts.archive(primary), throwsA(isA<StateError>()));
    expect(() => accounts.delete(primary), throwsA(isA<StateError>()));
  });

  test('update archives delete and audit trail', () async {
    final accounts = await repo();
    accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final loanId = accounts.create(
      AccountDraft(
        name: 'Car Loan',
        type: AccountType.loan,
        openingBalanceCents: 100000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    accounts.update(
      loanId,
      const AccountUpdate(name: 'Auto Loan', interestRateApr: 6.5),
    );
    expect(accounts.getById(loanId)!.name, 'Auto Loan');
    expect(accounts.getById(loanId)!.interestRateApr, 6.5);

    accounts.archive(loanId);
    expect(accounts.listAccounts(), hasLength(1));
    expect(accounts.listAccounts(includeArchived: true), hasLength(2));
    expect(accounts.getById(loanId)!.isArchived, isTrue);

    accounts.unarchive(loanId);
    expect(accounts.listAccounts(), hasLength(2));

    accounts.delete(loanId);
    expect(accounts.getById(loanId), isNull);

    final actions = AuditLogRepository(harness.session)
        .recent()
        .where((e) => e['entity_id'] == loanId)
        .map((e) => e['action'])
        .toSet();
    expect(
      actions,
      containsAll([
        AuditAction.create,
        AuditAction.update,
        AuditAction.archive,
        AuditAction.delete,
      ]),
    );
  });

  test('update persists credentials without auditing secrets', () async {
    final accounts = await repo();
    final id = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    accounts.update(
      id,
      const AccountUpdate(
        loginUrl: 'https://bank.example/login',
        loginUsername: 'pat',
        loginPassword: 'vault-secret',
        contactEmail: 'pat@example.com',
        notes: 'Call before large transfers',
      ),
    );

    final updated = accounts.getById(id)!;
    expect(updated.loginUrl, 'https://bank.example/login');
    expect(updated.loginUsername, 'pat');
    expect(updated.loginPassword, 'vault-secret');
    expect(updated.contactEmail, 'pat@example.com');
    expect(updated.notes, 'Call before large transfers');

    final auditJson = AuditLogRepository(harness.session)
        .recent()
        .map((e) => '${e['summary']}|${e['detail_json']}')
        .join('\n');
    expect(auditJson, isNot(contains('vault-secret')));
  });

  test('create with isPrimary transfers from previous primary', () async {
    final accounts = await repo();
    final oldId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Old',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final newId = accounts.create(
      AccountDraft(
        name: 'New Primary',
        type: AccountType.checking,
        isPrimary: true,
        openingBalanceCents: 10,
        openingDate: DateTime(2026, 7, 2),
      ),
    );

    expect(accounts.primaryAccountId(), newId);
    expect(accounts.getById(oldId)!.isPrimary, isFalse);
  });
}
