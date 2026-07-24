import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'account.dart';
import 'account_type.dart';
import 'audit_categories.dart';
import 'audit_log_repository.dart';
import 'database_session.dart';

class PrimaryCheckingDraft {
  const PrimaryCheckingDraft({
    required this.name,
    this.institution,
    required this.openingBalanceCents,
    required this.openingDate,
  });

  final String name;
  final String? institution;
  final int openingBalanceCents;
  final DateTime openingDate;
}

/// Account CRUD with primary-flag rules and audit writes (Phase 1.1).
class AccountRepository {
  AccountRepository(this._session, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final DatabaseSession _session;
  final Uuid _uuid;

  Database get _db => _session.database;
  AuditLogRepository get _audit => AuditLogRepository(_session);

  bool hasPrimaryAccount() => primaryAccountId() != null;

  String? primaryAccountId() {
    final rows = _db.select(
      '''
SELECT id FROM accounts
WHERE is_primary = 1 AND is_archived = 0
LIMIT 1
''',
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as String;
  }

  Account? getById(String id) {
    final rows = _db.select('SELECT * FROM accounts WHERE id = ? LIMIT 1', [id]);
    if (rows.isEmpty) {
      return null;
    }
    return Account.fromRow(rows.first);
  }

  List<Account> listAccounts({bool includeArchived = false}) {
    final rows = includeArchived
        ? _db.select(
            '''
SELECT * FROM accounts
ORDER BY is_primary DESC, name COLLATE NOCASE ASC, id ASC
''',
          )
        : _db.select(
            '''
SELECT * FROM accounts
WHERE is_archived = 0
ORDER BY is_primary DESC, name COLLATE NOCASE ASC, id ASC
''',
          );
    return rows.map(Account.fromRow).toList();
  }

  /// Creates the primary checking account and an opening-balance transaction.
  ///
  /// Fails if a primary already exists (use [setPrimary] / [create] to transfer).
  String createPrimaryChecking(PrimaryCheckingDraft draft) {
    if (hasPrimaryAccount()) {
      throw StateError('A primary account already exists');
    }
    return create(
      AccountDraft(
        name: draft.name,
        type: AccountType.checking,
        institution: draft.institution,
        isPrimary: true,
        openingBalanceCents: draft.openingBalanceCents,
        openingDate: draft.openingDate,
      ),
    );
  }

  /// Creates an account and an opening-balance transaction.
  String create(AccountDraft draft) {
    final name = _requireName(draft.name);
    if (draft.isPrimary && draft.type != AccountType.checking) {
      throw ArgumentError('Only a checking account can be primary');
    }
    if (draft.isPrimary && hasPrimaryAccount()) {
      // Transfer is allowed: clear previous primary inside the transaction.
    } else if (draft.isPrimary == false &&
        draft.type == AccountType.checking &&
        !hasPrimaryAccount()) {
      // First checking may be created non-primary; wizard uses isPrimary true.
    }

    if (draft.paymentDueDay != null) {
      _validateDueDay(draft.paymentDueDay!);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final openingDate = _dateOnly(draft.openingDate);
    final accountId = _uuid.v4();
    final txId = _uuid.v4();
    final includeInDebt =
        draft.includeInDebtList ?? draft.type.defaultIncludeInDebtList;

    _db.execute('BEGIN IMMEDIATE');
    try {
      if (draft.isPrimary) {
        _clearPrimaryFlags();
      }

      _db.execute(
        '''
INSERT INTO accounts (
  id, name, type, institution, account_number, login_url, login_username,
  login_password, contact_name, contact_phone, contact_email, notes,
  interest_rate_apr, minimum_payment_cents, payment_due_day, currency_code,
  is_primary, is_archived, include_in_debt_list,
  opening_balance_cents, opening_date, created_at, updated_at
) VALUES (
  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?
)
''',
        [
          accountId,
          name,
          draft.type.dbValue,
          _nullIfBlank(draft.institution),
          _nullIfBlank(draft.accountNumber),
          _nullIfBlank(draft.loginUrl),
          _nullIfBlank(draft.loginUsername),
          _nullIfBlank(draft.loginPassword),
          _nullIfBlank(draft.contactName),
          _nullIfBlank(draft.contactPhone),
          _nullIfBlank(draft.contactEmail),
          _nullIfBlank(draft.notes),
          draft.interestRateApr,
          draft.minimumPaymentCents,
          draft.paymentDueDay,
          draft.currencyCode,
          draft.isPrimary ? 1 : 0,
          includeInDebt ? 1 : 0,
          draft.openingBalanceCents,
          openingDate,
          now,
          now,
        ],
      );

      _db.execute(
        '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, 1, ?, 'opening_balance', ?, ?)
''',
        [
          txId,
          accountId,
          openingDate,
          'Opening Balance',
          'Initial balance',
          draft.openingBalanceCents,
          now,
          now,
          now,
        ],
      );

      if (draft.isPrimary) {
        _setPrimarySetting(accountId);
      }

      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.create,
        entityType: AuditEntityType.account,
        entityId: accountId,
        summary: 'Created account "$name"',
        detail: {
          'type': draft.type.dbValue,
          'is_primary': draft.isPrimary,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }

    return accountId;
  }

  /// Updates mutable account fields (not opening balance/date).
  void update(String id, AccountUpdate patch) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Account not found');
    }
    if (existing.isArchived) {
      throw StateError('Cannot update an archived account; unarchive first');
    }

    final nextName = patch.name == null ? existing.name : _requireName(patch.name!);
    final nextType = patch.type ?? existing.type;
    if (existing.isPrimary && nextType != AccountType.checking) {
      throw ArgumentError('Primary account must remain type checking');
    }
    if (patch.paymentDueDay != null) {
      _validateDueDay(patch.paymentDueDay!);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final institution = patch.institution ?? existing.institution;
    final accountNumber = patch.accountNumber ?? existing.accountNumber;
    final loginUrl = patch.loginUrl ?? existing.loginUrl;
    final loginUsername = patch.loginUsername ?? existing.loginUsername;
    final loginPassword = patch.clearLoginPassword
        ? null
        : (patch.loginPassword ?? existing.loginPassword);
    final contactName = patch.contactName ?? existing.contactName;
    final contactPhone = patch.contactPhone ?? existing.contactPhone;
    final contactEmail = patch.contactEmail ?? existing.contactEmail;
    final notes = patch.notes ?? existing.notes;
    final interestRateApr = patch.clearInterestRateApr
        ? null
        : (patch.interestRateApr ?? existing.interestRateApr);
    final minimumPaymentCents = patch.clearMinimumPaymentCents
        ? null
        : (patch.minimumPaymentCents ?? existing.minimumPaymentCents);
    final paymentDueDay = patch.clearPaymentDueDay
        ? null
        : (patch.paymentDueDay ?? existing.paymentDueDay);
    final currencyCode = patch.currencyCode ?? existing.currencyCode;
    final includeInDebtList =
        patch.includeInDebtList ?? existing.includeInDebtList;

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE accounts SET
  name = ?, type = ?, institution = ?, account_number = ?, login_url = ?,
  login_username = ?, login_password = ?, contact_name = ?, contact_phone = ?,
  contact_email = ?, notes = ?, interest_rate_apr = ?, minimum_payment_cents = ?,
  payment_due_day = ?, currency_code = ?, include_in_debt_list = ?, updated_at = ?
WHERE id = ?
''',
        [
          nextName,
          nextType.dbValue,
          _nullIfBlank(institution),
          _nullIfBlank(accountNumber),
          _nullIfBlank(loginUrl),
          _nullIfBlank(loginUsername),
          _nullIfBlank(loginPassword),
          _nullIfBlank(contactName),
          _nullIfBlank(contactPhone),
          _nullIfBlank(contactEmail),
          _nullIfBlank(notes),
          interestRateApr,
          minimumPaymentCents,
          paymentDueDay,
          currencyCode,
          includeInDebtList ? 1 : 0,
          now,
          id,
        ],
      );

      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.update,
        entityType: AuditEntityType.account,
        entityId: id,
        summary: 'Updated account "$nextName"',
        detail: {
          'type': nextType.dbValue,
          if (nextName != existing.name) 'renamed_from': existing.name,
        },
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Makes [id] the sole primary checking account.
  void setPrimary(String id) {
    final account = getById(id);
    if (account == null) {
      throw StateError('Account not found');
    }
    if (account.isArchived) {
      throw StateError('Cannot make an archived account primary');
    }
    if (account.type != AccountType.checking) {
      throw ArgumentError('Only a checking account can be primary');
    }
    if (account.isPrimary) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _clearPrimaryFlags();
      _db.execute(
        'UPDATE accounts SET is_primary = 1, updated_at = ? WHERE id = ?',
        [now, id],
      );
      _setPrimarySetting(id);
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.update,
        entityType: AuditEntityType.account,
        entityId: id,
        summary: 'Set primary account to "${account.name}"',
        detail: {'is_primary': true},
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void archive(String id) {
    final account = getById(id);
    if (account == null) {
      throw StateError('Account not found');
    }
    if (account.isArchived) {
      return;
    }
    if (account.isPrimary) {
      throw StateError(
        'Cannot archive the primary account; set another primary first',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE accounts SET is_archived = 1, updated_at = ? WHERE id = ?',
        [now, id],
      );
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.archive,
        entityType: AuditEntityType.account,
        entityId: id,
        summary: 'Archived account "${account.name}"',
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void unarchive(String id) {
    final account = getById(id);
    if (account == null) {
      throw StateError('Account not found');
    }
    if (!account.isArchived) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE accounts SET is_archived = 0, updated_at = ? WHERE id = ?',
        [now, id],
      );
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.update,
        entityType: AuditEntityType.account,
        entityId: id,
        summary: 'Unarchived account "${account.name}"',
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Permanently deletes an account and its transactions.
  ///
  /// Refuses to delete the primary account.
  void delete(String id) {
    final account = getById(id);
    if (account == null) {
      throw StateError('Account not found');
    }
    if (account.isPrimary) {
      throw StateError(
        'Cannot delete the primary account; set another primary first',
      );
    }

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM transactions WHERE account_id = ?', [id]);
      _db.execute('DELETE FROM recurrence_rules WHERE account_id = ?', [id]);
      _db.execute(
        'UPDATE recurrence_rules SET linked_account_id = NULL WHERE linked_account_id = ?',
        [id],
      );
      _db.execute('DELETE FROM accounts WHERE id = ?', [id]);
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.delete,
        entityType: AuditEntityType.account,
        entityId: id,
        summary: 'Deleted account "${account.name}"',
        detail: {'type': account.type.dbValue},
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _clearPrimaryFlags() {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      'UPDATE accounts SET is_primary = 0, updated_at = ? WHERE is_primary = 1',
      [now],
    );
  }

  void _setPrimarySetting(String accountId) {
    _db.execute(
      '''
INSERT INTO app_settings (key, value) VALUES ('primary_account_id', ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value
''',
      [accountId],
    );
  }

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Account name is required');
    }
    return trimmed;
  }

  static void _validateDueDay(int day) {
    if (day < 1 || day > 31) {
      throw ArgumentError('payment_due_day must be between 1 and 31');
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
