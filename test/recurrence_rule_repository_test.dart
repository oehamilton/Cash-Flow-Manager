import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/audit_categories.dart';
import 'package:cash_flow_manager/data/audit_log_repository.dart';
import 'package:cash_flow_manager/data/recurrence_frequency.dart';
import 'package:cash_flow_manager/data/recurrence_rule.dart';
import 'package:cash_flow_manager/data/recurrence_rule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<(String accountId, RecurrenceRuleRepository rules)> setup() async {
    await harness.createUnlockedVault();
    final accountId = AccountRepository(harness.session).createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    return (accountId, RecurrenceRuleRepository(harness.session));
  }

  test('create/list/update/delete with audit', () async {
    final (accountId, rules) = await setup();
    final id = rules.create(
      RecurrenceRuleDraft(
        accountId: accountId,
        payee: 'Payroll',
        amountCents: 220000,
        frequency: RecurrenceFrequency.biweekly,
        anchorDate: DateTime(2026, 7, 3),
      ),
    );

    final listed = rules.listForAccount(accountId);
    expect(listed, hasLength(1));
    expect(listed.single.payee, 'Payroll');
    expect(listed.single.frequency, RecurrenceFrequency.biweekly);
    // Materialize advances next_scheduled past the ~2-month horizon.
    expect(listed.single.nextScheduledDate, isNotNull);

    rules.update(
      id,
      const RecurrenceRuleUpdate(
        payee: 'Payroll Direct',
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      ),
    );
    expect(rules.getById(id)!.payee, 'Payroll Direct');
    expect(rules.getById(id)!.frequency, RecurrenceFrequency.weekly);
    expect(rules.getById(id)!.interval, 2);

    final audit = AuditLogRepository(harness.session).recent();
    expect(
      audit.any(
        (e) =>
            e['entity_type'] == AuditEntityType.recurrenceRule &&
            e['action'] == AuditAction.create &&
            e['entity_id'] == id,
      ),
      isTrue,
    );

    rules.delete(id);
    expect(rules.listForAccount(accountId), isEmpty);
    expect(
      AuditLogRepository(harness.session).recent().any(
            (e) =>
                e['action'] == AuditAction.delete &&
                e['entity_type'] == AuditEntityType.recurrenceRule,
          ),
      isTrue,
    );
  });

  test('rejects empty payee and zero amount', () async {
    final (accountId, rules) = await setup();
    expect(
      () => rules.create(
        RecurrenceRuleDraft(
          accountId: accountId,
          payee: '  ',
          amountCents: 100,
          frequency: RecurrenceFrequency.monthly,
          anchorDate: DateTime(2026, 7, 1),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => rules.create(
        RecurrenceRuleDraft(
          accountId: accountId,
          payee: 'Rent',
          amountCents: 0,
          frequency: RecurrenceFrequency.monthly,
          anchorDate: DateTime(2026, 7, 1),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('activeOnly listing and setActive', () async {
    final (accountId, rules) = await setup();
    final id = rules.create(
      RecurrenceRuleDraft(
        accountId: accountId,
        payee: 'Gym',
        amountCents: -4500,
        frequency: RecurrenceFrequency.monthly,
        anchorDate: DateTime(2026, 7, 1),
      ),
    );
    rules.setActive(id, active: false);
    expect(rules.listForAccount(accountId, activeOnly: true), isEmpty);
    expect(rules.listForAccount(accountId), hasLength(1));
    expect(rules.getById(id)!.isActive, isFalse);
  });

  test('RecurrenceFrequency.parse covers planned values', () {
    for (final f in RecurrenceFrequency.values) {
      expect(RecurrenceFrequency.parse(f.dbValue), f);
    }
  });
}
