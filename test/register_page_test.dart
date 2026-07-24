import 'package:cash_flow_manager/app_shell/app_shell.dart';
import 'package:cash_flow_manager/app_shell/app_destination.dart';
import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/money.dart';
import 'package:cash_flow_manager/features/register/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  testWidgets('RegisterPage empty state without session', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterPage(auth: null, accountId: null),
      ),
    );
    expect(find.byKey(const Key('page_register')), findsOneWidget);
    expect(find.byKey(const Key('register_empty')), findsOneWidget);
  });

  test('cold start prefers primary; open register can target another account',
      () async {
    final harness = TempVaultHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await harness.createUnlockedVault();
    final repo = AccountRepository(harness.session);
    final primaryId = repo.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Primary Checking',
        openingBalanceCents: 5000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final savingsId = repo.create(
      AccountDraft(
        name: 'Savings',
        type: AccountType.savings,
        openingBalanceCents: 9000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    expect(repo.primaryAccountId(), primaryId);
    expect(repo.balanceCents(primaryId), 5000);
    expect(repo.balanceCents(savingsId), 9000);
    expect(formatCents(9000), r'$90.00');
  });

  testWidgets('AppShell Open register switches destination key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(initialDestination: AppDestination.accounts),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('page_accounts')), findsOneWidget);
    expect(find.byKey(const Key('destination_accounts')), findsOneWidget);
  });
}
