import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/extra_payment_hint.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

AccountSummary _summary({
  required String id,
  required String name,
  required double? apr,
  required int balanceCents,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return AccountSummary(
    account: Account(
      id: id,
      name: name,
      type: AccountType.creditCard,
      interestRateApr: apr,
      isPrimary: false,
      isArchived: false,
      includeInDebtList: true,
      openingBalanceCents: balanceCents,
      openingDate: DateTime(2026, 1, 1),
      createdAt: now,
      updatedAt: now,
    ),
    balanceCents: balanceCents,
  );
}

void main() {
  group('ExtraPaymentHint', () {
    test('sortByAprDesc puts highest APR first; nulls last', () {
      final sorted = ExtraPaymentHint.sortByAprDesc([
        _summary(id: 'a', name: 'Low', apr: 12, balanceCents: 1000),
        _summary(id: 'b', name: 'High', apr: 24.9, balanceCents: 500),
        _summary(id: 'c', name: 'None', apr: null, balanceCents: 2000),
      ]);
      expect(sorted.map((s) => s.account.name).toList(), ['High', 'Low', 'None']);
    });

    test('fromPrimary computes surplus and highest-APR target', () {
      final hint = ExtraPaymentHint.fromPrimary(
        primaryMetrics: const RegisterMetrics(
          reconciledCents: 10000,
          todayCents: 12000,
          trough4WeeksCents: 8000,
          trough8WeeksCents: 7000,
        ),
        debts: [
          _summary(id: 'a', name: 'Store card', apr: 19.9, balanceCents: 40000),
          _summary(id: 'b', name: 'Bank card', apr: 22.5, balanceCents: 20000),
        ],
      );
      expect(hint, isNotNull);
      // No min balance → suggest full 4-week trough.
      expect(hint!.surplusCents, 8000);
      expect(hint.minBalanceCents, 0);
      expect(hint.targetDebt!.account.name, 'Bank card');
      expect(hint.hasSurplus, isTrue);
    });

    test('suggested payment is trough minus min balance', () {
      // Matches UI case: $4114.47 low − $1000 min → $3114.47
      final hint = ExtraPaymentHint.fromPrimary(
        primaryMetrics: const RegisterMetrics(
          reconciledCents: 400000,
          todayCents: 461447,
          trough4WeeksCents: 411447,
        ),
        debts: [
          _summary(id: 'b', name: 'Capital One', apr: 25.4, balanceCents: 20000),
        ],
        minBalanceCents: 100000,
      );
      expect(hint!.surplusCents, 311447);
      expect(hint.minBalanceCents, 100000);
      expect(hint.hasSurplus, isTrue);
    });

    test('surplus clamps at zero when trough is at or below min balance', () {
      final hint = ExtraPaymentHint.fromPrimary(
        primaryMetrics: const RegisterMetrics(
          reconciledCents: 0,
          todayCents: 8000,
          trough4WeeksCents: 5000,
        ),
        debts: [
          _summary(id: 'a', name: 'Loan', apr: 8, balanceCents: 90000),
        ],
        minBalanceCents: 5000,
      );
      expect(hint!.surplusCents, 0);
      expect(hint.hasSurplus, isFalse);
      expect(hint.targetDebt!.account.name, 'Loan');
    });

    test('zero or credit (negative) debt balances are not targets', () {
      final hint = ExtraPaymentHint.fromPrimary(
        primaryMetrics: const RegisterMetrics(
          reconciledCents: 0,
          todayCents: 10000,
          trough4WeeksCents: 8000,
        ),
        debts: [
          _summary(id: 'a', name: 'Paid off', apr: 29.9, balanceCents: 0),
          _summary(id: 'b', name: 'Credit', apr: 19.9, balanceCents: -500),
          _summary(id: 'c', name: 'Still owed', apr: 12.0, balanceCents: 1000),
        ],
      );
      expect(hint!.targetDebt!.account.name, 'Still owed');
    });
  });

  group('debts list APR order', () {
    final harness = TempVaultHarness();

    setUp(harness.setUp);
    tearDown(harness.tearDown);

    test('listSummaries debtsOnly sorts by APR descending', () async {
      await harness.createUnlockedVault();
      final accounts = AccountRepository(harness.session);
      accounts.createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 20000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      accounts.create(
        AccountDraft(
          name: 'Cheap',
          type: AccountType.loan,
          interestRateApr: 9.0,
          openingBalanceCents: 50000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      accounts.create(
        AccountDraft(
          name: 'Expensive',
          type: AccountType.creditCard,
          interestRateApr: 27.0,
          openingBalanceCents: 10000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );

      final debts = accounts.listSummaries(debtsOnly: true);
      expect(debts.map((d) => d.account.name).toList(), ['Expensive', 'Cheap']);

      final primaryId = accounts.primaryAccountId()!;
      final txs = TransactionRepository(harness.session);
      txs.create(
        TransactionDraft(
          accountId: primaryId,
          date: DateTime(2026, 8, 1),
          payee: 'Future bill',
          amountCents: -5000,
        ),
        asOf: DateTime(2026, 7, 10),
      );
      final metrics = txs.metricsFor(primaryId, asOf: DateTime(2026, 7, 10));
      final hint = ExtraPaymentHint.fromPrimary(
        primaryMetrics: metrics,
        debts: debts,
      );
      expect(hint!.targetDebt!.account.name, 'Expensive');
      expect(hint.surplusCents, greaterThan(0));
    });
  });
}
