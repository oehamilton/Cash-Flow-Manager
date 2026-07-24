import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'account_repository.dart';
import 'account_history.dart';
import 'audit_categories.dart';
import 'audit_log_repository.dart';
import 'database_session.dart';
import 'forecast_trough.dart';
import 'payee_repository.dart';
import 'payee_suggestion.dart';
import 'recurrence_materializer.dart';
import 'transaction.dart';
import 'transfer_amounts.dart';

/// Transaction CRUD scoped by account, with payee history and audit (Phase 2.1).
///
/// Phase 6.1 adds linked transfer pairs via [transfer_pair_id].
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

  /// Other leg of a transfer pair, if any.
  Transaction? transferCounterpart(String id) {
    final existing = getById(id);
    if (existing == null || existing.transferPairId == null) {
      return null;
    }
    final rows = _db.select(
      '''
SELECT * FROM transactions
WHERE transfer_pair_id = ? AND id != ?
LIMIT 1
''',
      [existing.transferPairId, id],
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

  /// Trailing 12 month-end balances and tagged interest paid (Phase 4.2).
  List<AccountMonthPoint> trailingTwelveMonths(
    String accountId, {
    DateTime? asOf,
  }) {
    final end = asOf ?? DateTime.now();
    return [
      for (final monthStart in AccountHistory.trailingMonthStarts(end))
        AccountMonthPoint(
          monthStart: monthStart,
          balanceCents: balanceOnOrBefore(
            accountId,
            AccountHistory.monthEndCap(monthStart, end),
          ),
          interestPaidCents: interestPaidInMonth(
            accountId,
            monthStart,
            through: AccountHistory.monthEndCap(monthStart, end),
          ),
        ),
    ];
  }

  /// Sum of non-null interest tags for txs in [monthStart] through [through].
  int interestPaidInMonth(
    String accountId,
    DateTime monthStart, {
    required DateTime through,
  }) {
    final from = _dateOnly(monthStart);
    final to = _dateOnly(through);
    final row = _db.select(
      '''
SELECT COALESCE(SUM(interest_cents), 0) AS total
FROM transactions
WHERE account_id = ?
  AND interest_cents IS NOT NULL
  AND date >= ?
  AND date <= ?
''',
      [accountId, from, to],
    ).first;
    return row['total'] as int;
  }

  /// Sticky header metrics including 4/8-week forecast troughs (Phase 3.5).
  RegisterMetrics metricsFor(String accountId, {DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    final todayCents = balanceOnOrBefore(accountId, today);
    final entries = listRegisterEntries(accountId);
    return RegisterMetrics(
      reconciledCents: clearedBalanceCents(accountId),
      todayCents: todayCents,
      trough4WeeksCents: ForecastTrough.lowestInHorizon(
        balanceThroughToday: todayCents,
        entries: entries,
        asOf: today,
        horizonDays: ForecastTrough.weeks4Days,
      ),
      trough8WeeksCents: ForecastTrough.lowestInHorizon(
        balanceThroughToday: todayCents,
        entries: entries,
        asOf: today,
        horizonDays: ForecastTrough.weeks8Days,
      ),
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

  /// Account payees + managed payees + history strings (Phase 6).
  List<PayeeSuggestion> combinedPayeeSuggestions(
    String accountId, {
    String prefix = '',
    int limit = 24,
  }) {
    final q = prefix.trim().toLowerCase();
    final accounts = AccountRepository(_session).listAccounts();
    final managed = PayeeRepository(_session).listAll();
    final history = payeeSuggestions(accountId, prefix: prefix, limit: limit);
    final accountNames = {
      for (final a in accounts) a.name.toLowerCase(),
    };

    final out = <PayeeSuggestion>[];
    for (final account in accounts) {
      if (account.id == accountId) {
        continue;
      }
      if (q.isNotEmpty && !account.name.toLowerCase().contains(q)) {
        continue;
      }
      out.add(AccountPayeeSuggestion(account));
    }
    for (final payee in managed) {
      if (q.isNotEmpty && !payee.name.toLowerCase().contains(q)) {
        continue;
      }
      out.add(ManagedPayeeSuggestion(payee));
    }
    for (final name in history) {
      if (accountNames.contains(name.toLowerCase())) {
        continue;
      }
      if (managed.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
        continue;
      }
      out.add(TextPayeeSuggestion(name));
    }
    return out.take(limit).toList();
  }

  /// Creates a manual transaction and writes an audit row.
  ///
  /// When [TransactionDraft.transferToAccountId] is set, also creates the
  /// counterpart leg (Phase 6.1).
  String create(TransactionDraft draft, {DateTime? asOf}) {
    _requireAccount(draft.accountId);
    final transferTo = draft.transferToAccountId;
    if (transferTo != null) {
      return _createTransfer(draft, transferTo, asOf: asOf);
    }

    final payee = _nullIfBlank(draft.payee);
    final memo = _nullIfBlank(draft.memo);
    final date = _dateOnly(draft.date);
    final source = TransactionSource.manualForDate(draft.date, asOf: asOf);
    validateInterestPrincipalSplit(
      amountCents: draft.amountCents,
      interestCents: draft.interestCents,
      principalCents: draft.principalCents,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source,
  payee_id, interest_cents, principal_cents,
  created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?)
''',
        [
          id,
          draft.accountId,
          date,
          payee,
          memo,
          draft.amountCents,
          source,
          draft.payeeId,
          draft.interestCents,
          draft.principalCents,
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
          if (draft.payeeId != null) 'payee_id': draft.payeeId,
          if (draft.interestCents != null)
            'interest_cents': draft.interestCents,
          if (draft.principalCents != null)
            'principal_cents': draft.principalCents,
        },
      );

      _db.execute('COMMIT');
      return id;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  String _createTransfer(
    TransactionDraft draft,
    String destAccountId, {
    DateTime? asOf,
  }) {
    if (destAccountId == draft.accountId) {
      throw ArgumentError('Cannot transfer to the same account');
    }
    final accounts = AccountRepository(_session);
    final source = accounts.getById(draft.accountId);
    final dest = accounts.getById(destAccountId);
    if (source == null || dest == null) {
      throw ArgumentError('Account not found');
    }

    final date = _dateOnly(draft.date);
    final sourceAmount = draft.amountCents;
    final destAmount = TransferAmounts.counterpartAmount(
      sourceType: source.type,
      destType: dest.type,
      sourceAmountCents: sourceAmount,
    );
    final sourceLabel = dest.name;
    final destLabel = source.name;
    final memo = _nullIfBlank(draft.memo);
    final sourceKind = TransactionSource.manualForDate(draft.date, asOf: asOf);
    final now = DateTime.now().toUtc().toIso8601String();
    final pairId = _uuid.v4();
    final sourceId = _uuid.v4();
    final destId = _uuid.v4();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _insertTransferLeg(
        id: sourceId,
        accountId: source.id,
        date: date,
        payee: sourceLabel,
        memo: memo,
        amountCents: sourceAmount,
        source: sourceKind,
        transferPairId: pairId,
        now: now,
      );
      _insertTransferLeg(
        id: destId,
        accountId: dest.id,
        date: date,
        payee: destLabel,
        memo: memo,
        amountCents: destAmount,
        source: sourceKind,
        transferPairId: pairId,
        now: now,
      );

      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.create,
        entityType: AuditEntityType.transaction,
        entityId: sourceId,
        summary: _summary('Created transfer', sourceLabel, sourceAmount),
        detail: {
          'account_id': source.id,
          'transfer_pair_id': pairId,
          'counterpart_account_id': dest.id,
          'counterpart_transaction_id': destId,
          'date': date,
          'amount_cents': sourceAmount,
        },
      );
      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.create,
        entityType: AuditEntityType.transaction,
        entityId: destId,
        summary: _summary('Created transfer', destLabel, destAmount),
        detail: {
          'account_id': dest.id,
          'transfer_pair_id': pairId,
          'counterpart_account_id': source.id,
          'counterpart_transaction_id': sourceId,
          'date': date,
          'amount_cents': destAmount,
        },
      );

      _db.execute('COMMIT');
      return sourceId;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _insertTransferLeg({
    required String id,
    required String accountId,
    required String date,
    required String payee,
    required String? memo,
    required int amountCents,
    required String source,
    required String transferPairId,
    required String now,
  }) {
    _db.execute(
      '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source,
  transfer_pair_id, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, 0, NULL, ?, ?, ?, ?)
''',
      [
        id,
        accountId,
        date,
        payee,
        memo,
        amountCents,
        source,
        transferPairId,
        now,
        now,
      ],
    );
  }

  /// Marks a transaction cleared or uncleared and writes an audit row.
  ///
  /// Clear state is independent per transfer leg (Phase 6.1).
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
  ///
  /// Transfer legs stay in sync for date/amount. Changing away from an account
  /// payee deletes the counterpart and clears [transfer_pair_id].
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

    final wantsTransfer = patch.transferToAccountId != null;
    final clearTransfer = patch.clearTransfer;
    final wasTransfer = existing.transferPairId != null;

    if (wantsTransfer || (wasTransfer && !clearTransfer)) {
      _updateTransferAware(existing, patch, asOf: asOf);
      return;
    }

    if (wasTransfer && clearTransfer) {
      _unlinkAndUpdate(existing, patch, asOf: asOf);
      return;
    }

    _updateSingle(existing, patch, asOf: asOf);
  }

  void _updateTransferAware(
    Transaction existing,
    TransactionUpdate patch, {
    DateTime? asOf,
  }) {
    final accounts = AccountRepository(_session);
    final sourceAccount = accounts.getById(existing.accountId)!;
    final counterpart = transferCounterpart(existing.id);

    final nextDestId = patch.transferToAccountId ??
        counterpart?.accountId;
    if (nextDestId == null) {
      throw StateError('Transfer counterpart missing');
    }
    if (nextDestId == existing.accountId) {
      throw ArgumentError('Cannot transfer to the same account');
    }
    final destAccount = accounts.getById(nextDestId);
    if (destAccount == null) {
      throw ArgumentError('Account not found');
    }

    final nextDate =
        patch.date != null ? _dateOnly(patch.date!) : _dateOnly(existing.date);
    final amount = patch.amountCents ?? existing.amountCents;
    final destAmount = TransferAmounts.counterpartAmount(
      sourceType: sourceAccount.type,
      destType: destAccount.type,
      sourceAmountCents: amount,
    );
    final String? nextMemo;
    if (patch.clearMemo) {
      nextMemo = null;
    } else if (patch.memo != null) {
      nextMemo = _nullIfBlank(patch.memo);
    } else {
      nextMemo = existing.memo;
    }
    final nextSource = TransactionSource.isUserManual(existing.source)
        ? TransactionSource.manualForDate(
            patch.date ?? existing.date,
            asOf: asOf,
          )
        : existing.source;
    final markOverridden = existing.isRecurringGenerated;
    final now = DateTime.now().toUtc().toIso8601String();
    final pairId = existing.transferPairId ?? _uuid.v4();

    _db.execute('BEGIN IMMEDIATE');
    try {
      if (counterpart != null && counterpart.isCleared) {
        throw StateError(
          'Counterpart transfer is cleared; unclear it before editing',
        );
      }

      _db.execute(
        '''
UPDATE transactions SET
  date = ?,
  payee = ?,
  memo = ?,
  amount_cents = ?,
  source = ?,
  transfer_pair_id = ?,
  payee_id = NULL,
  interest_cents = NULL,
  principal_cents = NULL,
  is_user_overridden = CASE WHEN ? = 1 THEN 1 ELSE is_user_overridden END,
  updated_at = ?
WHERE id = ?
''',
        [
          nextDate,
          destAccount.name,
          nextMemo,
          amount,
          nextSource,
          pairId,
          markOverridden ? 1 : 0,
          now,
          existing.id,
        ],
      );

      if (counterpart == null) {
        final destId = _uuid.v4();
        _insertTransferLeg(
          id: destId,
          accountId: destAccount.id,
          date: nextDate,
          payee: sourceAccount.name,
          memo: nextMemo,
          amountCents: destAmount,
          source: nextSource,
          transferPairId: pairId,
          now: now,
        );
      } else {
        final destSource = TransactionSource.isUserManual(counterpart.source)
            ? nextSource
            : counterpart.source;
        final destOverride = counterpart.isRecurringGenerated;
        _db.execute(
          '''
UPDATE transactions SET
  account_id = ?,
  date = ?,
  payee = ?,
  memo = ?,
  amount_cents = ?,
  source = ?,
  transfer_pair_id = ?,
  payee_id = NULL,
  interest_cents = NULL,
  principal_cents = NULL,
  is_user_overridden = CASE WHEN ? = 1 THEN 1 ELSE is_user_overridden END,
  updated_at = ?
WHERE id = ?
''',
          [
            destAccount.id,
            nextDate,
            sourceAccount.name,
            nextMemo,
            destAmount,
            destSource,
            pairId,
            destOverride ? 1 : 0,
            now,
            counterpart.id,
          ],
        );
      }

      final updated = getById(existing.id)!;
      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.update,
        entityType: AuditEntityType.transaction,
        entityId: existing.id,
        summary: _summary('Updated transfer', updated.payee, updated.amountCents),
        detail: {
          'account_id': updated.accountId,
          'transfer_pair_id': pairId,
          'counterpart_account_id': destAccount.id,
          'date': nextDate,
          'amount_cents': updated.amountCents,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _unlinkAndUpdate(
    Transaction existing,
    TransactionUpdate patch, {
    DateTime? asOf,
  }) {
    final counterpart = transferCounterpart(existing.id);
    if (counterpart != null && counterpart.isCleared) {
      throw StateError(
        'Counterpart transfer is cleared; unclear it before unlinking',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN IMMEDIATE');
    try {
      if (counterpart != null) {
        _db.execute('DELETE FROM transactions WHERE id = ?', [counterpart.id]);
        _audit.append(
          category: AuditCategory.transaction,
          action: AuditAction.delete,
          entityType: AuditEntityType.transaction,
          entityId: counterpart.id,
          summary: _summary(
            'Deleted transfer leg',
            counterpart.payee,
            counterpart.amountCents,
          ),
          detail: {
            'account_id': counterpart.accountId,
            'transfer_pair_id': existing.transferPairId,
            'unlinked_from': existing.id,
          },
        );
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
      final nextPayeeId = patch.clearPayeeId
          ? null
          : (patch.payeeId ?? existing.payeeId);

      _db.execute(
        '''
UPDATE transactions SET
  date = ?,
  payee = ?,
  memo = ?,
  amount_cents = ?,
  source = ?,
  transfer_pair_id = NULL,
  payee_id = ?,
  updated_at = ?
WHERE id = ?
''',
        [
          nextDate,
          nextPayee,
          nextMemo,
          amount,
          nextSource,
          nextPayeeId,
          now,
          existing.id,
        ],
      );

      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.update,
        entityType: AuditEntityType.transaction,
        entityId: existing.id,
        summary: _summary('Unlinked transfer', nextPayee, amount),
        detail: {
          'account_id': existing.accountId,
          'date': nextDate,
          'amount_cents': amount,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _updateSingle(
    Transaction existing,
    TransactionUpdate patch, {
    DateTime? asOf,
  }) {
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
    final int? nextInterest;
    if (patch.clearInterest) {
      nextInterest = null;
    } else if (patch.interestCents != null) {
      nextInterest = patch.interestCents;
    } else {
      nextInterest = existing.interestCents;
    }
    final int? nextPrincipal;
    if (patch.clearPrincipal) {
      nextPrincipal = null;
    } else if (patch.principalCents != null) {
      nextPrincipal = patch.principalCents;
    } else {
      nextPrincipal = existing.principalCents;
    }
    validateInterestPrincipalSplit(
      amountCents: amount,
      interestCents: nextInterest,
      principalCents: nextPrincipal,
    );
    final nextSource = TransactionSource.isUserManual(existing.source)
        ? TransactionSource.manualForDate(
            patch.date ?? existing.date,
            asOf: asOf,
          )
        : existing.source;
    final markOverridden = existing.isRecurringGenerated;
    final nextPayeeId = patch.clearPayeeId
        ? null
        : (patch.payeeId ?? (patch.clearPayee ? null : existing.payeeId));
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
  payee_id = ?,
  interest_cents = ?,
  principal_cents = ?,
  is_user_overridden = CASE WHEN ? = 1 THEN 1 ELSE is_user_overridden END,
  updated_at = ?
WHERE id = ?
''',
        [
          nextDate,
          nextPayee,
          nextMemo,
          amount,
          nextSource,
          nextPayeeId,
          nextInterest,
          nextPrincipal,
          markOverridden ? 1 : 0,
          now,
          existing.id,
        ],
      );

      final updated = getById(existing.id)!;
      _audit.append(
        category: AuditCategory.transaction,
        action: AuditAction.update,
        entityType: AuditEntityType.transaction,
        entityId: existing.id,
        summary: _summary('Updated', updated.payee, updated.amountCents),
        detail: {
          'account_id': updated.accountId,
          'date': _dateOnly(updated.date),
          'payee': updated.payee,
          'amount_cents': updated.amountCents,
          'source': updated.source,
          if (updated.isUserOverridden) 'is_user_overridden': true,
          if (updated.payeeId != null) 'payee_id': updated.payeeId,
          if (updated.interestCents != null)
            'interest_cents': updated.interestCents,
          if (updated.principalCents != null)
            'principal_cents': updated.principalCents,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes a transaction; opening-balance and cleared rows are protected.
  ///
  /// Transfer pairs: both legs are deleted (Phase 6.1).
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

    final counterpart = transferCounterpart(id);
    if (counterpart != null && counterpart.isCleared) {
      throw StateError(
        'Counterpart transfer is cleared; unclear it before deleting',
      );
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      // Prevent rematerialize from recreating this occurrence (and its pair).
      RecurrenceMaterializer.recordSkipForTransactions(
        _db,
        primary: existing,
        counterpart: counterpart,
      );

      if (counterpart != null) {
        _db.execute('DELETE FROM transactions WHERE id = ?', [counterpart.id]);
        _audit.append(
          category: AuditCategory.transaction,
          action: AuditAction.delete,
          entityType: AuditEntityType.transaction,
          entityId: counterpart.id,
          summary: _summary(
            'Deleted',
            counterpart.payee,
            counterpart.amountCents,
          ),
          detail: {
            'account_id': counterpart.accountId,
            'date': _dateOnly(counterpart.date),
            'payee': counterpart.payee,
            'amount_cents': counterpart.amountCents,
            'source': counterpart.source,
            'transfer_pair_id': existing.transferPairId,
          },
        );
      }

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
          if (existing.transferPairId != null)
            'transfer_pair_id': existing.transferPairId,
          if (existing.recurrenceInstanceKey != null)
            'recurrence_instance_key': existing.recurrenceInstanceKey,
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
