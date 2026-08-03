import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'account_repository.dart';
import 'database_session.dart';
import 'recurrence_rule.dart';
import 'recurrence_rule_repository.dart';
import 'recurrence_schedule.dart';
import 'transaction.dart';
import 'transfer_amounts.dart';

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
/// When [RecurrenceRule.linkedAccountId] is set, also creates the counterpart
/// transfer leg (Phase 6.3).
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
    // Also materialize rules on other accounts that transfer *into* this one.
    final inbound = RecurrenceRuleRepository(_session).listAllActive().where(
          (r) => r.linkedAccountId == accountId && r.accountId != accountId,
        );
    final seen = <String>{};
    var inserted = 0;
    var skipped = 0;
    var processed = 0;
    for (final rule in [...rules, ...inbound]) {
      if (!seen.add(rule.id)) {
        continue;
      }
      final partial = materializeRule(
        rule,
        asOf: asOf,
        horizonDays: horizonDays,
      );
      inserted += partial.inserted;
      skipped += partial.skippedExisting;
      processed++;
    }
    return MaterializeResult(
      inserted: inserted,
      skippedExisting: skipped,
      rulesProcessed: processed,
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

    final accounts = AccountRepository(_session);
    final sourceAccount = accounts.getById(rule.accountId);
    final linked = rule.linkedAccountId == null
        ? null
        : accounts.getById(rule.linkedAccountId!);

    var inserted = 0;
    var skipped = 0;
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final date in dates) {
        final key = instanceKey(rule.id, date);
        if (_isSkipped(rule.id, key)) {
          skipped++;
          continue;
        }
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

        final pairId =
            linked != null && sourceAccount != null ? _uuid.v4() : null;
        final sourcePayee = linked != null ? linked.name : rule.payee;
        final destAmount = linked != null && sourceAccount != null
            ? TransferAmounts.counterpartAmount(
                sourceType: sourceAccount.type,
                destType: linked.type,
                sourceAmountCents: rule.amountCents,
              )
            : null;

        _db.execute(
          '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source,
  recurrence_rule_id, recurrence_instance_key, transfer_pair_id,
  created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
          [
            _uuid.v4(),
            rule.accountId,
            RecurrenceSchedule.formatDate(date),
            sourcePayee,
            rule.memo,
            rule.amountCents,
            rule.autoClear ? 1 : 0,
            rule.autoClear ? now : null,
            TransactionSource.recurringGenerated,
            rule.id,
            key,
            pairId,
            now,
            now,
          ],
        );
        inserted++;

        if (linked != null &&
            sourceAccount != null &&
            pairId != null &&
            destAmount != null) {
          final destKey = counterpartInstanceKey(rule.id, date);
          if (_isSkipped(rule.id, destKey)) {
            continue;
          }
          final destExisting = _db.select(
            '''
SELECT id FROM transactions
WHERE account_id = ? AND recurrence_instance_key = ?
LIMIT 1
''',
            [linked.id, destKey],
          );
          if (destExisting.isEmpty) {
            _db.execute(
              '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source,
  recurrence_rule_id, recurrence_instance_key, transfer_pair_id,
  created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
              [
                _uuid.v4(),
                linked.id,
                RecurrenceSchedule.formatDate(date),
                sourceAccount.name,
                rule.memo,
                destAmount,
                0,
                null,
                TransactionSource.recurringGenerated,
                rule.id,
                destKey,
                pairId,
                now,
                now,
              ],
            );
            inserted++;
          }
        }
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

  static String counterpartInstanceKey(String ruleId, DateTime date) =>
      '$ruleId:${RecurrenceSchedule.formatDate(date)}:xfer';

  bool _isSkipped(String ruleId, String instanceKey) {
    final rows = _db.select(
      '''
SELECT 1 AS ok FROM recurrence_instance_skips
WHERE recurrence_rule_id = ? AND instance_key = ?
LIMIT 1
''',
      [ruleId, instanceKey],
    );
    return rows.isNotEmpty;
  }

  /// Records that a generated occurrence must not be rematerialized.
  ///
  /// For transfer pairs, both the source and `:xfer` keys are skipped.
  static void recordSkipForTransactions(
    Database db, {
    required Transaction primary,
    Transaction? counterpart,
  }) {
    final ruleId =
        primary.recurrenceRuleId ?? counterpart?.recurrenceRuleId;
    if (ruleId == null) {
      return;
    }
    final generated = primary.isRecurringGenerated ||
        (counterpart?.isRecurringGenerated ?? false);
    if (!generated) {
      return;
    }

    final keys = <String>{};
    for (final tx in [primary, ?counterpart]) {
      final key = tx.recurrenceInstanceKey;
      if (key == null || key.isEmpty) {
        continue;
      }
      keys.add(key);
      if (key.endsWith(':xfer')) {
        keys.add(key.substring(0, key.length - ':xfer'.length));
      } else {
        keys.add('$key:xfer');
      }
    }
    if (keys.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    for (final key in keys) {
      db.execute(
        '''
INSERT OR IGNORE INTO recurrence_instance_skips (
  recurrence_rule_id, instance_key, skipped_at
) VALUES (?, ?, ?)
''',
        [ruleId, key, now],
      );
    }
  }
}
