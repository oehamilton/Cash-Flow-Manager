import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'database_session.dart';
import 'recurrence_rule.dart';
import 'recurrence_rule_repository.dart';
import 'recurrence_schedule.dart';
import 'transaction.dart';

/// Result of a materialization pass.
class MaterializeResult {
  const MaterializeResult({
    required this.inserted,
    required this.skippedExisting,
    required this.rulesProcessed,
  });

  final int inserted;
  final int skippedExisting;
  final int rulesProcessed;
}

/// Generates uncleared register rows for active recurrence rules (Phase 3.2).
///
/// Instance keys are `{ruleId}:{YYYY-MM-DD}` so re-runs are idempotent.
class RecurrenceMaterializer {
  RecurrenceMaterializer(this._session, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final DatabaseSession _session;
  final Uuid _uuid;

  Database get _db => _session.database;

  /// Default forecast window (~2 months).
  static const defaultHorizonDays = 62;

  MaterializeResult materializeAll({
    DateTime? asOf,
    int horizonDays = defaultHorizonDays,
  }) {
    final rules = RecurrenceRuleRepository(_session).listAllActive();
    var inserted = 0;
    var skipped = 0;
    for (final rule in rules) {
      final partial = materializeRule(
        rule,
        asOf: asOf,
        horizonDays: horizonDays,
      );
      inserted += partial.inserted;
      skipped += partial.skippedExisting;
    }
    return MaterializeResult(
      inserted: inserted,
      skippedExisting: skipped,
      rulesProcessed: rules.length,
    );
  }

  MaterializeResult materializeAccount(
    String accountId, {
    DateTime? asOf,
    int horizonDays = defaultHorizonDays,
  }) {
    final rules = RecurrenceRuleRepository(_session).listForAccount(
      accountId,
      activeOnly: true,
    );
    var inserted = 0;
    var skipped = 0;
    for (final rule in rules) {
      final partial = materializeRule(
        rule,
        asOf: asOf,
        horizonDays: horizonDays,
      );
      inserted += partial.inserted;
      skipped += partial.skippedExisting;
    }
    return MaterializeResult(
      inserted: inserted,
      skippedExisting: skipped,
      rulesProcessed: rules.length,
    );
  }

  MaterializeResult materializeRule(
    RecurrenceRule rule, {
    DateTime? asOf,
    int horizonDays = defaultHorizonDays,
  }) {
    if (!rule.isActive) {
      return const MaterializeResult(
        inserted: 0,
        skippedExisting: 0,
        rulesProcessed: 0,
      );
    }

    final today = RecurrenceSchedule.dateOnly(asOf ?? DateTime.now());
    final horizonEnd = today.add(Duration(days: horizonDays));
    final dates = RecurrenceSchedule.occurrencesInRange(
      anchor: rule.anchorDate,
      start: today,
      end: horizonEnd,
      frequency: rule.frequency,
      interval: rule.interval,
      ruleEnd: rule.endDate,
    );

    var inserted = 0;
    var skipped = 0;
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final date in dates) {
        final key = instanceKey(rule.id, date);
        final existing = _db.select(
          '''
SELECT id FROM transactions
WHERE account_id = ? AND recurrence_instance_key = ?
LIMIT 1
''',
          [rule.accountId, key],
        );
        if (existing.isNotEmpty) {
          skipped++;
          continue;
        }

        _db.execute(
          '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source,
  recurrence_rule_id, recurrence_instance_key,
  created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
          [
            _uuid.v4(),
            rule.accountId,
            RecurrenceSchedule.formatDate(date),
            rule.payee,
            rule.memo,
            rule.amountCents,
            rule.autoClear ? 1 : 0,
            rule.autoClear ? now : null,
            TransactionSource.recurringGenerated,
            rule.id,
            key,
            now,
            now,
          ],
        );
        inserted++;
      }

      // Point next_scheduled at the first occurrence after the horizon.
      final nextAfterHorizon = RecurrenceSchedule.occurrencesInRange(
        anchor: rule.anchorDate,
        start: horizonEnd.add(const Duration(days: 1)),
        end: horizonEnd.add(const Duration(days: 366)),
        frequency: rule.frequency,
        interval: rule.interval,
        ruleEnd: rule.endDate,
      );
      final next = nextAfterHorizon.isEmpty
          ? null
          : RecurrenceSchedule.formatDate(nextAfterHorizon.first);
      _db.execute(
        '''
UPDATE recurrence_rules
SET next_scheduled_date = ?, updated_at = ?
WHERE id = ?
''',
        [next, now, rule.id],
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }

    return MaterializeResult(
      inserted: inserted,
      skippedExisting: skipped,
      rulesProcessed: 1,
    );
  }

  static String instanceKey(String ruleId, DateTime date) =>
      '$ruleId:${RecurrenceSchedule.formatDate(date)}';
}
