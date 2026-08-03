import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/recurrence_frequency.dart';
import 'package:cash_flow_manager/data/recurrence_materializer.dart';
import 'package:cash_flow_manager/data/recurrence_rule.dart';
import 'package:cash_flow_manager/data/recurrence_rule_repository.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('uncleared generated rows can be edited and stay overridden', () async {
    await harness.createUnlockedVault();
    final accountId = AccountRepository(harness.session).createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final rules = RecurrenceRuleRepository(harness.session);
    final asOf = DateTime(2026, 7, 15);
    final ruleId = rules.create(
      RecurrenceRuleDraft(
        accountId: accountId,
        payee: 'Payroll',
        amountCents: 200000,
        frequency: RecurrenceFrequency.biweekly,
        anchorDate: DateTime(2026, 7, 31),
      ),
    );
    final materializer = RecurrenceMaterializer(harness.session);
    materializer.materializeRule(
      rules.getById(ruleId)!,
      asOf: asOf,
      horizonDays: 62,
    );

    final txs = TransactionRepository(harness.session);
    final generated = txs
        .listForAccount(accountId)
        .where((t) => t.recurrenceRuleId == ruleId)
        .toList();
    expect(generated, isNotEmpty);
    final target = generated.first;
    expect(target.isRecurringGenerated, isTrue);
    expect(target.isUserOverridden, isFalse);
    final originalKey = target.recurrenceInstanceKey;

    txs.update(
      target.id,
      const TransactionUpdate(
        payee: 'Payroll adjusted',
        amountCents: 210000,
      ),
      asOf: asOf,
    );

    final edited = txs.getById(target.id)!;
    expect(edited.payee, 'Payroll adjusted');
    expect(edited.amountCents, 210000);
    expect(edited.isUserOverridden, isTrue);
    expect(edited.source, TransactionSource.recurringGenerated);
    expect(edited.recurrenceInstanceKey, originalKey);

    final rematerialize = materializer.materializeRule(
      rules.getById(ruleId)!,
      asOf: asOf,
      horizonDays: 62,
    );
    expect(rematerialize.inserted, 0);
    expect(txs.getById(target.id)!.amountCents, 210000);
    expect(txs.getById(target.id)!.isUserOverridden, isTrue);
  });

  test('cleared generated rows cannot be edited', () async {
    await harness.createUnlockedVault();
    final accountId = AccountRepository(harness.session).createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final rules = RecurrenceRuleRepository(harness.session);
    final asOf = DateTime(2026, 7, 15);
    final ruleId = rules.create(
      RecurrenceRuleDraft(
        accountId: accountId,
        payee: 'Rent',
        amountCents: -120000,
        frequency: RecurrenceFrequency.monthly,
        anchorDate: DateTime(2026, 8, 1),
      ),
    );
    RecurrenceMaterializer(harness.session).materializeRule(
      rules.getById(ruleId)!,
      asOf: asOf,
      horizonDays: 62,
    );

    final txs = TransactionRepository(harness.session);
    final generated = txs
        .listForAccount(accountId)
        .firstWhere((t) => t.recurrenceRuleId == ruleId);
    txs.setCleared(generated.id, cleared: true);

    expect(
      () => txs.update(
        generated.id,
        const TransactionUpdate(amountCents: -100000),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cleared'),
        ),
      ),
    );
  });
}
