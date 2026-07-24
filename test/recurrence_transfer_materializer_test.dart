import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/recurrence_frequency.dart';
import 'package:cash_flow_manager/data/recurrence_materializer.dart';
import 'package:cash_flow_manager/data/recurrence_rule.dart';
import 'package:cash_flow_manager/data/recurrence_rule_repository.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('linked_account_id materializes paired transfer legs', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final checkingId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 200000,
        openingDate: DateTime(2026, 1, 1),
      ),
    );
    final cardId = accounts.create(
      AccountDraft(
        name: 'Visa',
        type: AccountType.creditCard,
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 1, 1),
      ),
    );

    final asOf = DateTime(2026, 7, 1);
    RecurrenceRuleRepository(harness.session).create(
      RecurrenceRuleDraft(
        accountId: checkingId,
        linkedAccountId: cardId,
        payee: 'Visa',
        amountCents: -15000,
        frequency: RecurrenceFrequency.monthly,
        anchorDate: DateTime(2026, 7, 15),
      ),
    );

    final result = RecurrenceMaterializer(harness.session).materializeAccount(
      checkingId,
      asOf: asOf,
    );
    expect(result.inserted, greaterThanOrEqualTo(2));

    final txs = TransactionRepository(harness.session);
    final checkingXfers = txs
        .listForAccount(checkingId)
        .where((t) => t.isTransfer && t.isRecurringGenerated)
        .toList();
    expect(checkingXfers, isNotEmpty);
    final counterpart = txs.transferCounterpart(checkingXfers.first.id)!;
    expect(counterpart.accountId, cardId);
    expect(counterpart.amountCents, -15000);
    expect(checkingXfers.first.amountCents, -15000);
  });
}
