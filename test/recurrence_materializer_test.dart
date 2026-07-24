import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/recurrence_frequency.dart';
import 'package:cash_flow_manager/data/recurrence_materializer.dart';
import 'package:cash_flow_manager/data/recurrence_rule.dart';
import 'package:cash_flow_manager/data/recurrence_rule_repository.dart';
import 'package:cash_flow_manager/data/recurrence_schedule.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  group('RecurrenceSchedule', () {
    test('monthly occurrences stay on day-of-month', () {
      final dates = RecurrenceSchedule.occurrencesInRange(
        anchor: DateTime(2026, 1, 15),
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 4, 30),
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
      );
      expect(
        dates.map(RecurrenceSchedule.formatDate).toList(),
        ['2026-01-15', '2026-02-15', '2026-03-15', '2026-04-15'],
      );
    });

    test('weekly respects interval', () {
      final next = RecurrenceSchedule.nextOccurrence(
        DateTime(2026, 7, 1),
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      );
      expect(RecurrenceSchedule.formatDate(next), '2026-07-15');
    });

    test('parseDateOnly keeps calendar day (no UTC shift)', () {
      final parsed = RecurrenceSchedule.parseDateOnly('2026-07-31');
      expect(parsed, DateTime(2026, 7, 31));
      expect(parsed.isUtc, isFalse);
    });

    test('rule end date truncates range', () {
      final dates = RecurrenceSchedule.occurrencesInRange(
        anchor: DateTime(2026, 7, 1),
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 31),
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        ruleEnd: DateTime(2026, 7, 15),
      );
      expect(dates, hasLength(3)); // 1, 8, 15
    });
  });

  group('RecurrenceMaterializer', () {
    final harness = TempVaultHarness();

    setUp(harness.setUp);
    tearDown(harness.tearDown);

    test('inserts generated txs with idempotent keys', () async {
      await harness.createUnlockedVault();
      final accountId =
          AccountRepository(harness.session).createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 10000,
          openingDate: DateTime(2026, 6, 1),
        ),
      );
      // Create without going through repository materialize side-effect path
      // timing — repository create also materializes; use asOf for determinism.
      final rules = RecurrenceRuleRepository(harness.session);
      final asOf = DateTime(2026, 7, 1);
      final ruleId = rules.create(
        RecurrenceRuleDraft(
          accountId: accountId,
          payee: 'Rent',
          amountCents: -120000,
          frequency: RecurrenceFrequency.monthly,
          anchorDate: DateTime(2026, 7, 1),
        ),
      );

      final materializer = RecurrenceMaterializer(harness.session);
      // Align window with create()'s side-effect pass (uses DateTime.now()).
      materializer.materializeRule(
        rules.getById(ruleId)!,
        asOf: asOf,
        horizonDays: 62,
      );

      final txs = TransactionRepository(harness.session)
          .listForAccount(accountId)
          .where((t) => t.source == TransactionSource.recurringGenerated)
          .toList();
      expect(txs, isNotEmpty);
      expect(txs.every((t) => t.payee == 'Rent'), isTrue);
      expect(txs.every((t) => t.recurrenceRuleId == ruleId), isTrue);
      expect(
        txs.every(
          (t) => t.recurrenceInstanceKey!.startsWith('$ruleId:'),
        ),
        isTrue,
      );

      final second = materializer.materializeRule(
        rules.getById(ruleId)!,
        asOf: asOf,
        horizonDays: 62,
      );
      expect(second.inserted, 0);
      expect(second.skippedExisting, txs.length);
    });

    test('biweekly deposit fills ~2 month horizon with multiple rows', () async {
      await harness.createUnlockedVault();
      final accountId =
          AccountRepository(harness.session).createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 10000,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      final rules = RecurrenceRuleRepository(harness.session);
      final asOf = DateTime(2026, 7, 24);
      final ruleId = rules.create(
        RecurrenceRuleDraft(
          accountId: accountId,
          payee: 'Paycheck',
          amountCents: 150000,
          frequency: RecurrenceFrequency.biweekly,
          interval: 1,
          anchorDate: DateTime(2026, 7, 31),
        ),
      );

      // create() uses DateTime.now(); align deterministically.
      RecurrenceMaterializer(harness.session).materializeRule(
        rules.getById(ruleId)!,
        asOf: asOf,
        horizonDays: 62,
      );

      final dates = TransactionRepository(harness.session)
          .listForAccount(accountId)
          .where(
            (t) =>
                t.source == TransactionSource.recurringGenerated &&
                t.recurrenceRuleId == ruleId,
          )
          .map((t) => RecurrenceSchedule.formatDate(t.date))
          .toList();

      expect(
        dates,
        ['2026-07-31', '2026-08-14', '2026-08-28', '2026-09-11'],
      );
    });

    test('auto_clear marks generated rows cleared', () async {
      await harness.createUnlockedVault();
      final accountId =
          AccountRepository(harness.session).createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 0,
          openingDate: DateTime(2026, 7, 1),
        ),
      );
      RecurrenceRuleRepository(harness.session).create(
        RecurrenceRuleDraft(
          accountId: accountId,
          payee: 'Payroll',
          amountCents: 100000,
          frequency: RecurrenceFrequency.weekly,
          anchorDate: DateTime(2026, 7, 3),
          autoClear: true,
        ),
      );

      final generated = TransactionRepository(harness.session)
          .listForAccount(accountId)
          .where((t) => t.source == TransactionSource.recurringGenerated);
      expect(generated, isNotEmpty);
      expect(generated.every((t) => t.isCleared), isTrue);
    });
  });
}
