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

  test('deleted recurring instance is not rematerialized', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    final checkingId = accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 200000,
        openingDate: DateTime(2026, 1, 1),
      ),
    );

    final asOf = DateTime(2026, 7, 1);
    RecurrenceRuleRepository(harness.session).create(
      RecurrenceRuleDraft(
        accountId: checkingId,
        payee: 'Netflix',
        amountCents: -1500,
        frequency: RecurrenceFrequency.monthly,
        anchorDate: DateTime(2026, 7, 15),
      ),
    );

    final materializer = RecurrenceMaterializer(harness.session);
    materializer.materializeAccount(checkingId, asOf: asOf);

    final txs = TransactionRepository(harness.session);
    final generated = txs
        .listForAccount(checkingId)
        .where((t) => t.isRecurringGenerated)
        .toList();
    expect(generated, isNotEmpty);

    final target = generated.first;
    txs.delete(target.id);

    materializer.materializeAccount(checkingId, asOf: asOf);
    final after = txs
        .listForAccount(checkingId)
        .where(
          (t) =>
              t.isRecurringGenerated &&
              t.recurrenceInstanceKey == target.recurrenceInstanceKey,
        )
        .toList();
    expect(after, isEmpty);

    final skips = harness.session.database.select(
      'SELECT instance_key FROM recurrence_instance_skips',
    );
    expect(skips, isNotEmpty);
  });

  test('deleted recurring transfer removes both legs and stays gone', () async {
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

    final materializer = RecurrenceMaterializer(harness.session);
    materializer.materializeAccount(checkingId, asOf: asOf);

    final txs = TransactionRepository(harness.session);
    final checkingGen = txs
        .listForAccount(checkingId)
        .where((t) => t.isRecurringGenerated && t.isTransfer)
        .toList();
    expect(checkingGen, isNotEmpty);
    final source = checkingGen.first;
    final dest = txs.transferCounterpart(source.id);
    expect(dest, isNotNull);
    expect(dest!.accountId, cardId);

    txs.delete(source.id);

    expect(txs.getById(source.id), isNull);
    expect(txs.getById(dest.id), isNull);

    materializer.materializeAccount(checkingId, asOf: asOf);
    materializer.materializeAccount(cardId, asOf: asOf);

    expect(
      txs.listForAccount(checkingId).where(
            (t) => t.recurrenceInstanceKey == source.recurrenceInstanceKey,
          ),
      isEmpty,
    );
    expect(
      txs.listForAccount(cardId).where(
            (t) => t.recurrenceInstanceKey == dest.recurrenceInstanceKey,
          ),
      isEmpty,
    );
  });
}
