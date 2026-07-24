import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'audit_categories.dart';
import 'audit_log_repository.dart';
import 'database_session.dart';
import 'recurrence_rule.dart';

/// Recurrence rule CRUD with audit writes (Phase 3.1).
///
/// Materializing instances into the register arrives in Phase 3.2.
class RecurrenceRuleRepository {
  RecurrenceRuleRepository(this._session, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final DatabaseSession _session;
  final Uuid _uuid;

  Database get _db => _session.database;
  AuditLogRepository get _audit => AuditLogRepository(_session);

  RecurrenceRule? getById(String id) {
    final rows = _db.select(
      'SELECT * FROM recurrence_rules WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return RecurrenceRule.fromRow(rows.first);
  }

  List<RecurrenceRule> listForAccount(
    String accountId, {
    bool activeOnly = false,
  }) {
    final rows = activeOnly
        ? _db.select(
            '''
SELECT * FROM recurrence_rules
WHERE account_id = ? AND is_active = 1
ORDER BY payee COLLATE NOCASE ASC, id ASC
''',
            [accountId],
          )
        : _db.select(
            '''
SELECT * FROM recurrence_rules
WHERE account_id = ?
ORDER BY is_active DESC, payee COLLATE NOCASE ASC, id ASC
''',
            [accountId],
          );
    return rows.map(RecurrenceRule.fromRow).toList();
  }

  String create(RecurrenceRuleDraft draft) {
    _requireAccount(draft.accountId);
    final payee = _requirePayee(draft.payee);
    _validateInterval(draft.interval);
    if (draft.amountCents == 0) {
      throw ArgumentError('Amount cannot be zero');
    }
    if (draft.linkedAccountId != null) {
      _requireAccount(draft.linkedAccountId!);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    final anchor = _dateOnly(draft.anchorDate);
    final end = draft.endDate == null ? null : _dateOnly(draft.endDate!);
    if (end != null && end.compareTo(anchor) < 0) {
      throw ArgumentError('End date cannot be before anchor date');
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
INSERT INTO recurrence_rules (
  id, account_id, linked_account_id, payee, memo, amount_cents,
  frequency, interval, anchor_date, next_scheduled_date, end_date,
  auto_clear, is_active, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        [
          id,
          draft.accountId,
          draft.linkedAccountId,
          payee,
          _nullIfBlank(draft.memo),
          draft.amountCents,
          draft.frequency.dbValue,
          draft.interval,
          anchor,
          anchor, // next run starts at anchor until 3.2 advances it
          end,
          draft.autoClear ? 1 : 0,
          draft.isActive ? 1 : 0,
          now,
          now,
        ],
      );

      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.create,
        entityType: AuditEntityType.recurrenceRule,
        entityId: id,
        summary: 'Created recurrence "$payee" (${draft.frequency.dbValue})',
        detail: {
          'account_id': draft.accountId,
          'payee': payee,
          'amount_cents': draft.amountCents,
          'frequency': draft.frequency.dbValue,
          'interval': draft.interval,
          'anchor_date': anchor,
        },
      );

      _db.execute('COMMIT');
      return id;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void update(String id, RecurrenceRuleUpdate patch) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Recurrence rule not found');
    }

    final payee = patch.payee != null
        ? _requirePayee(patch.payee!)
        : existing.payee;
    final memo = patch.clearMemo
        ? null
        : (patch.memo != null ? _nullIfBlank(patch.memo) : existing.memo);
    final amount = patch.amountCents ?? existing.amountCents;
    if (amount == 0) {
      throw ArgumentError('Amount cannot be zero');
    }
    final frequency = patch.frequency ?? existing.frequency;
    final interval = patch.interval ?? existing.interval;
    _validateInterval(interval);
    final anchor = patch.anchorDate != null
        ? _dateOnly(patch.anchorDate!)
        : _dateOnly(existing.anchorDate);
    final String? end;
    if (patch.clearEndDate) {
      end = null;
    } else if (patch.endDate != null) {
      end = _dateOnly(patch.endDate!);
    } else {
      end = existing.endDate == null ? null : _dateOnly(existing.endDate!);
    }
    if (end != null && end.compareTo(anchor) < 0) {
      throw ArgumentError('End date cannot be before anchor date');
    }

    final String? linked;
    if (patch.clearLinkedAccountId) {
      linked = null;
    } else if (patch.linkedAccountId != null) {
      _requireAccount(patch.linkedAccountId!);
      linked = patch.linkedAccountId;
    } else {
      linked = existing.linkedAccountId;
    }

    final autoClear = patch.autoClear ?? existing.autoClear;
    final isActive = patch.isActive ?? existing.isActive;
    final now = DateTime.now().toUtc().toIso8601String();

    // Keep next_scheduled_date if still valid; otherwise reset to anchor.
    final nextExisting = existing.nextScheduledDate == null
        ? null
        : _dateOnly(existing.nextScheduledDate!);
    final next = (nextExisting != null && nextExisting.compareTo(anchor) >= 0)
        ? nextExisting
        : anchor;

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE recurrence_rules SET
  linked_account_id = ?,
  payee = ?,
  memo = ?,
  amount_cents = ?,
  frequency = ?,
  interval = ?,
  anchor_date = ?,
  next_scheduled_date = ?,
  end_date = ?,
  auto_clear = ?,
  is_active = ?,
  updated_at = ?
WHERE id = ?
''',
        [
          linked,
          payee,
          memo,
          amount,
          frequency.dbValue,
          interval,
          anchor,
          next,
          end,
          autoClear ? 1 : 0,
          isActive ? 1 : 0,
          now,
          id,
        ],
      );

      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.update,
        entityType: AuditEntityType.recurrenceRule,
        entityId: id,
        summary: 'Updated recurrence "$payee"',
        detail: {
          'account_id': existing.accountId,
          'payee': payee,
          'amount_cents': amount,
          'frequency': frequency.dbValue,
          'is_active': isActive,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void delete(String id) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Recurrence rule not found');
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      // Clear links from any generated txs (materialized later in 3.2).
      _db.execute(
        '''
UPDATE transactions SET
  recurrence_rule_id = NULL,
  recurrence_instance_key = NULL
WHERE recurrence_rule_id = ?
''',
        [id],
      );
      _db.execute('DELETE FROM recurrence_rules WHERE id = ?', [id]);

      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.delete,
        entityType: AuditEntityType.recurrenceRule,
        entityId: id,
        summary: 'Deleted recurrence "${existing.payee}"',
        detail: {
          'account_id': existing.accountId,
          'payee': existing.payee,
          'frequency': existing.frequency.dbValue,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void setActive(String id, {required bool active}) {
    update(id, RecurrenceRuleUpdate(isActive: active));
  }

  void _requireAccount(String accountId) {
    final rows = _db.select(
      'SELECT 1 AS ok FROM accounts WHERE id = ? LIMIT 1',
      [accountId],
    );
    if (rows.isEmpty) {
      throw ArgumentError('Account not found');
    }
  }

  static String _requirePayee(String payee) {
    final trimmed = payee.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Payee is required');
    }
    return trimmed;
  }

  static void _validateInterval(int interval) {
    if (interval < 1) {
      throw ArgumentError('Interval must be at least 1');
    }
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
