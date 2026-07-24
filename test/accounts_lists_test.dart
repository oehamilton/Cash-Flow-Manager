import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/money.dart';
import 'package:cash_flow_manager/features/accounts/accounts_page.dart';
import 'package:cash_flow_manager/features/accounts/debts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  group('AccountRepository summaries', () {
    final harness = TempVaultHarness();

    setUp(harness.setUp);
    tearDown(harness.tearDown);

    test('balanceCents sums transactions including opening balance', () async {
      await harness.seed(withSampleTransactions: true);
      final repo = AccountRepository(harness.session);
      final id = repo.primaryAccountId()!;
      // 150000 + 220000 - 8450 - 12500 - 50000 = 299050
      expect(repo.balanceCents(id), 299050);
    });

    test('listSummaries debtsOnly returns debt-flagged accounts', () async {
      await harness.createUnlockedVault();
      final repo = AccountRepository(harness.session);
      repo.createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 0,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      repo.create(
        AccountDraft(
          name: 'Card',
          type: AccountType.creditCard,
          interestRateApr: 22.9,
          minimumPaymentCents: 4500,
          paymentDueDay: 12,
          openingBalanceCents: 80000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );

      final debts = repo.listSummaries(debtsOnly: true);
      expect(debts, hasLength(1));
      expect(debts.single.account.name, 'Card');
      expect(debts.single.balanceCents, 80000);
    });

    test('listSummaries includes primary balance for accounts list', () async {
      await harness.createUnlockedVault();
      final repo = AccountRepository(harness.session);
      repo.createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Household Checking',
          openingBalanceCents: 10000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      repo.create(
        AccountDraft(
          name: 'Travel Card',
          type: AccountType.creditCard,
          interestRateApr: 19.99,
          minimumPaymentCents: 3500,
          paymentDueDay: 15,
          openingBalanceCents: 25000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );

      final rows = repo.listSummaries();
      expect(rows, hasLength(2));
      expect(rows.first.account.isPrimary, isTrue);
      expect(rows.first.balanceCents, 10000);
      expect(rows.last.account.name, 'Travel Card');
      expect(rows.last.balanceCents, 25000);

      final debts = repo.listSummaries(debtsOnly: true);
      expect(debts.single.account.name, 'Travel Card');
      expect(formatCents(debts.single.balanceCents), r'$250.00');
      expect(debts.single.account.interestRateApr, 19.99);
      expect(debts.single.account.minimumPaymentCents, 3500);
    });
  });

  testWidgets('AccountsPage empty state without session', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountsPage(auth: null)),
    );
    expect(find.byKey(const Key('accounts_empty')), findsOneWidget);
    expect(find.byKey(const Key('accounts_add_button')), findsOneWidget);
  });

  testWidgets('DebtsPage empty state without session', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DebtsPage(auth: null)),
    );
    expect(find.byKey(const Key('debts_empty')), findsOneWidget);
  });
}
