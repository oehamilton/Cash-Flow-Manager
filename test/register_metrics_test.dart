import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('metricsFor reports reconciled and today; troughs placeholder', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final txs = TransactionRepository(harness.session);
    final accountId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 5),
        payee: 'Store',
        amountCents: -2000,
      ),
    );
    // Future-dated relative to asOf — excluded from today.
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 8, 1),
        payee: 'Future Rent',
        amountCents: -5000,
      ),
    );

    final metrics = txs.metricsFor(
      accountId,
      asOf: DateTime(2026, 7, 10),
    );
    expect(metrics.reconciledCents, 10000); // opening only
    expect(metrics.todayCents, 8000); // opening + store
    expect(metrics.trough4WeeksCents, isNull);
    expect(metrics.trough8WeeksCents, isNull);

    final store = txs.listForAccount(accountId).firstWhere(
          (t) => t.payee == 'Store',
        );
    txs.setCleared(store.id, cleared: true);
    expect(
      txs.metricsFor(accountId, asOf: DateTime(2026, 7, 10)).reconciledCents,
      8000,
    );
  });

  test('balanceOnOrBefore is date-bounded', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final txs = TransactionRepository(harness.session);
    final accountId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 5000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 15),
        payee: 'Later',
        amountCents: 1000,
      ),
    );

    expect(
      txs.balanceOnOrBefore(accountId, DateTime(2026, 7, 10)),
      5000,
    );
    expect(
      txs.balanceOnOrBefore(accountId, DateTime(2026, 7, 15)),
      6000,
    );
  });
}
