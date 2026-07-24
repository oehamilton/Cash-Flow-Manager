import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('createPrimaryChecking inserts account and opening balance tx', () async {
    await harness.createUnlockedVault();
    final repo = AccountRepository(harness.session);
    expect(repo.hasPrimaryAccount(), isFalse);

    final id = repo.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Main Checking',
        institution: 'Test Bank',
        openingBalanceCents: 25000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    expect(repo.hasPrimaryAccount(), isTrue);
    expect(repo.primaryAccountId(), id);

    final accounts = harness.session.database.select(
      'SELECT name, type, is_primary, opening_balance_cents FROM accounts',
    );
    expect(accounts, hasLength(1));
    expect(accounts.first['name'], 'Main Checking');
    expect(accounts.first['type'], 'checking');
    expect(accounts.first['is_primary'], 1);
    expect(accounts.first['opening_balance_cents'], 25000);

    final txs = harness.session.database.select(
      'SELECT payee, amount_cents, source, is_cleared FROM transactions',
    );
    expect(txs, hasLength(1));
    expect(txs.first['payee'], 'Opening Balance');
    expect(txs.first['amount_cents'], 25000);
    expect(txs.first['source'], 'opening_balance');
    expect(txs.first['is_cleared'], 1);
  });
}
