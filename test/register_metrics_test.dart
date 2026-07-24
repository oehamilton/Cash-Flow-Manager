import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/forecast_trough.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  group('ForecastTrough', () {
    test('lowestInHorizon uses today when no future dips', () {
      final now = DateTime.utc(2026, 7, 1);
      final trough = ForecastTrough.lowestInHorizon(
        balanceThroughToday: 10000,
        entries: [
          RegisterEntry(
            transaction: Transaction(
              id: 'a',
              accountId: 'acct',
              date: DateTime(2026, 7, 20),
              amountCents: 5000,
              isCleared: false,
              source: TransactionSource.manualFuture,
              isUserOverridden: false,
              createdAt: now,
              updatedAt: now,
            ),
            runningBalanceCents: 15000,
          ),
        ],
        asOf: DateTime(2026, 7, 10),
        horizonDays: 28,
      );
      expect(trough, 10000);
    });

    test('lowestInHorizon finds future debit trough', () {
      final now = DateTime.utc(2026, 7, 1);
      final trough = ForecastTrough.lowestInHorizon(
        balanceThroughToday: 10000,
        entries: [
          RegisterEntry(
            transaction: Transaction(
              id: 'a',
              accountId: 'acct',
              date: DateTime(2026, 7, 20),
              amountCents: -4000,
              isCleared: false,
              source: TransactionSource.manualFuture,
              isUserOverridden: false,
              createdAt: now,
              updatedAt: now,
            ),
            runningBalanceCents: 6000,
          ),
          RegisterEntry(
            transaction: Transaction(
              id: 'b',
              accountId: 'acct',
              date: DateTime(2026, 8, 25),
              amountCents: -8000,
              isCleared: false,
              source: TransactionSource.manualFuture,
              isUserOverridden: false,
              createdAt: now,
              updatedAt: now,
            ),
            runningBalanceCents: -2000,
          ),
        ],
        asOf: DateTime(2026, 7, 10),
        horizonDays: 28, // through 2026-08-07 — excludes Aug 25
      );
      expect(trough, 6000);
    });
  });

  test('metricsFor reports reconciled, today, and trough lows', () async {
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
      asOf: DateTime(2026, 7, 10),
    );
    // Within 4 weeks from 7/10 → dips to 3000.
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 7, 25),
        payee: 'Car payment',
        amountCents: -5000,
      ),
      asOf: DateTime(2026, 7, 10),
    );
    // Outside 4 weeks, inside 8 weeks → dips to 1000.
    txs.create(
      TransactionDraft(
        accountId: accountId,
        date: DateTime(2026, 8, 20),
        payee: 'Insurance',
        amountCents: -2000,
      ),
      asOf: DateTime(2026, 7, 10),
    );

    final metrics = txs.metricsFor(
      accountId,
      asOf: DateTime(2026, 7, 10),
    );
    expect(metrics.reconciledCents, 10000); // opening only
    expect(metrics.todayCents, 8000); // opening + store
    expect(metrics.trough4WeeksCents, 3000); // after car payment
    expect(metrics.trough8WeeksCents, 1000); // after insurance

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
