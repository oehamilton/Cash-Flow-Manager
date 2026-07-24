import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sample_dataset.dart';
import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('TempVaultHarness creates an unlocked encrypted vault', () async {
    await harness.createUnlockedVault();
    expect(harness.auth.isUnlocked, isTrue);
    expect(await harness.auth.vaultExists(), isTrue);
    expect(AccountRepository(harness.session).hasPrimaryAccount(), isFalse);
  });

  test('SampleDataset seeds primary checking and register rows', () async {
    final seeded = await harness.seed();

    expect(seeded.primaryAccountId, isNotEmpty);
    expect(seeded.transactionIds, hasLength(4));
    expect(
      AccountRepository(harness.session).primaryAccountId(),
      seeded.primaryAccountId,
    );

    final txs = harness.session.database.select(
      '''
SELECT payee, amount_cents, is_cleared FROM transactions
WHERE source = 'manual' ORDER BY date
''',
    );
    expect(txs, hasLength(4));
    expect(txs.first['payee'], 'Payroll');
    expect(txs.first['amount_cents'], 220000);
    expect(txs.last['payee'], 'Transfer to Savings');
    expect(txs.last['is_cleared'], 0);
  });

  test('SampleDataset can seed primary without extra transactions', () async {
    final seeded = await harness.seed(withSampleTransactions: false);
    expect(seeded.transactionIds, isEmpty);

    final txs = harness.session.database.select(
      'SELECT COUNT(*) AS c FROM transactions',
    );
    // Opening balance only.
    expect(txs.first['c'], 1);
    expect(SampleDataset.defaultPrimary.name, 'Household Checking');
  });
}
