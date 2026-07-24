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

  /// Sum of cleared transactions (reconciled balance).
  int clearedBalanceCents(String accountId) {
    final row = _db.select(
      '''
SELECT COALESCE(SUM(amount_cents), 0) AS balance
FROM transactions
WHERE account_id = ? AND is_cleared = 1
''',
      [accountId],
    ).first;
    return row['balance'] as int;
  }

  /// Ledger total for transactions on or before [asOf] (calendar date).
  int balanceOnOrBefore(String accountId, DateTime asOf) {
    final date = _dateOnly(asOf);
    final row = _db.select(
      '''
SELECT COALESCE(SUM(amount_cents), 0) AS balance
FROM transactions
WHERE account_id = ? AND date <= ?
''',
      [accountId, date],
    ).first;
    return row['balance'] as int;
  }

  /// Sticky header metrics; troughs are placeholders until forecast lands.
  RegisterMetrics metricsFor(String accountId, {DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    return RegisterMetrics(
      reconciledCents: clearedBalanceCents(accountId),
      todayCents: balanceOnOrBefore(accountId, today),
    );
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
  ///
  /// Future-dated manuals are stored as [TransactionSource.manualFuture]
  /// (Phase 3.3).
  String create(TransactionDraft draft, {DateTime? asOf}) {
    _requireAccount(draft.accountId);
    final payee = _nullIfBlank(draft.payee);
    final memo = _nullIfBlank(draft.memo);
    final date = _dateOnly(draft.date);
    final source = TransactionSource.manualForDate(draft.date, asOf: asOf);
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
          source,
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
          'source': source,
        },
      );

      _db.execute('COMMIT');
      return id;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Marks a transaction cleared or uncleared and writes an audit row.
  void setCleared(String id, {required bool cleared}) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Transaction not found');
    }
    if (existing.isOpeningBalance && !cleared) {
      throw StateError('Opening balance cannot be uncleared');
    }
    if (existing.isCleared == cleared) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE transactions SET
  is_cleared = ?,
  cleared_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [cleared ? 1 : 0, cleared ? now : null, now, id],
      );

      _audit.append(
        category: AuditCategory.transaction,
        action: cleared ? AuditAction.clear : AuditAction.unclear,
        entityType: AuditEntityType.transaction,
        entityId: id,
        summary: _summary(
          cleared ? 'Cleared' : 'Uncleared',
          existing.payee,
          existing.amountCents,
        ),
        detail: {
          'account_id': existing.accountId,
          'date': _dateOnly(existing.date),
          'payee': existing.payee,
          'amount_cents': existing.amountCents,
          'is_cleared': cleared,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Finishes a statement reconcile when cleared balance matches the statement.
  void finishReconcile({
    required String accountId,
    required int statementEndingBalanceCents,
  }) {
    _requireAccount(accountId);
    final cleared = clearedBalanceCents(accountId);
    final difference = statementEndingBalanceCents - cleared;
    if (difference != 0) {
      throw StateError(
        'Cleared balance does not match statement '
        '(difference $difference cents)',
      );
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.reconcile,
        entityType: AuditEntityType.account,
        entityId: accountId,
        summary:
            'Reconciled to statement ending $statementEndingBalanceCents cents',
        detail: {
          'account_id': accountId,
          'statement_ending_balance_cents': statementEndingBalanceCents,
          'cleared_balance_cents': cleared,
          'difference_cents': 0,
        },
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Updates editable fields; opening-balance and cleared rows are protected.
  void update(String id, TransactionUpdate patch, {DateTime? asOf}) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Transaction not found');
    }
    if (existing.isOpeningBalance) {
      throw StateError('Opening balance cannot be edited');
    }
    if (existing.isCleared) {
      throw StateError('Cleared transactions cannot be edited; unclear first');
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
    final nextSource = TransactionSource.isUserManual(existing.source)
        ? TransactionSource.manualForDate(
            patch.date ?? existing.date,
            asOf: asOf,
          )
        : existing.source;
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
  source = ?,
  updated_at = ?
WHERE id = ?
''',
        [nextDate, nextPayee, nextMemo, amount, nextSource, now, id],
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
          'source': updated.source,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes a transaction; opening-balance and cleared rows are protected.
  void delete(String id) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Transaction not found');
    }
    if (existing.isOpeningBalance) {
      throw StateError('Opening balance cannot be deleted');
    }
    if (existing.isCleared) {
      throw StateError('Cleared transactions cannot be deleted; unclear first');
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
