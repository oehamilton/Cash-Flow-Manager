import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'audit_categories.dart';
import 'audit_log_repository.dart';
import 'database_session.dart';
import 'transaction.dart';

/// Transaction CRUD scoped by account, with payee history and audit (Phase 2.1).
class TransactionRepository {
  TransactionRepository(this._session, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final DatabaseSession _session;
  final Uuid _uuid;

  Database get _db => _session.database;
  AuditLogRepository get _audit => AuditLogRepository(_session);

  Transaction? getById(String id) {
    final rows = _db.select(
      'SELECT * FROM transactions WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Transaction.fromRow(rows.first);
  }

  /// Chronological register order (oldest first) for one account.
  List<Transaction> listForAccount(String accountId) {
    final rows = _db.select(
      '''
SELECT * FROM transactions
WHERE account_id = ?
ORDER BY date ASC, id ASC
''',
      [accountId],
    );
    return rows.map(Transaction.fromRow).toList();
  }

  /// Chronological rows with running balance after each transaction.
  List<RegisterEntry> listRegisterEntries(String accountId) {
    return withRunningBalances(listForAccount(accountId));
  }

  /// Distinct historical payees for autocomplete (case-insensitive prefix).
  List<String> payeeSuggestions(
    String accountId, {
    String prefix = '',
    int limit = 20,
  }) {
    final trimmed = prefix.trim();
    final rows = trimmed.isEmpty
        ? _db.select(
            '''
SELECT DISTINCT payee FROM transactions
WHERE account_id = ?
  AND payee IS NOT NULL
  AND TRIM(payee) != ''
ORDER BY payee COLLATE NOCASE ASC
LIMIT ?
''',
            [accountId, limit],
          )
        : _db.select(
            '''
SELECT DISTINCT payee FROM transactions
WHERE account_id = ?
  AND payee IS NOT NULL
  AND payee LIKE ? ESCAPE '\\'
ORDER BY payee COLLATE NOCASE ASC
LIMIT ?
''',
            [accountId, '${_likeEscape(trimmed)}%', limit],
          );
    return [
      for (final row in rows) row['payee'] as String,
    ];
  }

  /// Creates a manual transaction and writes an audit row.
  String create(TransactionDraft draft) {
    _requireAccount(draft.accountId);
    final payee = _nullIfBlank(draft.payee);
    final memo = _nullIfBlank(draft.memo);
    final date = _dateOnly(draft.date);
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, 0, NULL, ?, ?, ?)
''',
        [
          id,
          draft.accountId,
          date,
          payee,
          memo,
          draft.amountCents,
          TransactionSource.manual,
          now,
          now,
        ],
      );

      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.create,
        entityType: AuditEntityType.transaction,
        entityId: id,
        summary: _summary('Created', payee, draft.amountCents),
        detail: {
          'account_id': draft.accountId,
          'date': date,
          'payee': payee,
          'amount_cents': draft.amountCents,
          'source': TransactionSource.manual,
        },
      );

      _db.execute('COMMIT');
      return id;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Updates editable fields; opening-balance rows are protected.
  void update(String id, TransactionUpdate patch) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Transaction not found');
    }
    if (existing.isOpeningBalance) {
      throw StateError('Opening balance cannot be edited');
    }

    final nextDate =
        patch.date != null ? _dateOnly(patch.date!) : _dateOnly(existing.date);
    final String? nextPayee;
    if (patch.clearPayee) {
      nextPayee = null;
    } else if (patch.payee != null) {
      nextPayee = _nullIfBlank(patch.payee);
    } else {
      nextPayee = existing.payee;
    }
    final String? nextMemo;
    if (patch.clearMemo) {
      nextMemo = null;
    } else if (patch.memo != null) {
      nextMemo = _nullIfBlank(patch.memo);
    } else {
      nextMemo = existing.memo;
    }
    final amount = patch.amountCents ?? existing.amountCents;
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE transactions SET
  date = ?,
  payee = ?,
  memo = ?,
  amount_cents = ?,
  updated_at = ?
WHERE id = ?
''',
        [nextDate, nextPayee, nextMemo, amount, now, id],
      );

      final updated = getById(id)!;
      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.update,
        entityType: AuditEntityType.transaction,
        entityId: id,
        summary: _summary('Updated', updated.payee, updated.amountCents),
        detail: {
          'account_id': updated.accountId,
          'date': _dateOnly(updated.date),
          'payee': updated.payee,
          'amount_cents': updated.amountCents,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes a transaction; opening-balance rows are protected.
  void delete(String id) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Transaction not found');
    }
    if (existing.isOpeningBalance) {
      throw StateError('Opening balance cannot be deleted');
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM transactions WHERE id = ?', [id]);
      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.delete,
        entityType: AuditEntityType.transaction,
        entityId: id,
        summary: _summary('Deleted', existing.payee, existing.amountCents),
        detail: {
          'account_id': existing.accountId,
          'date': _dateOnly(existing.date),
          'payee': existing.payee,
          'amount_cents': existing.amountCents,
          'source': existing.source,
        },
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
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

  static String _summary(String verb, String? payee, int amountCents) {
    final label = (payee == null || payee.isEmpty) ? '(no payee)' : payee;
    return '$verb transaction "$label" ($amountCents cents)';
  }

  static String _likeEscape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
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
