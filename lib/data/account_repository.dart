import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

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

class AccountRepository {
  AccountRepository(this._session, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final DatabaseSession _session;
  final Uuid _uuid;

  Database get _db => _session.database;

  bool hasPrimaryAccount() {
    final rows = _db.select(
      'SELECT id FROM accounts WHERE is_primary = 1 AND is_archived = 0 LIMIT 1',
    );
    return rows.isNotEmpty;
  }

  String? primaryAccountId() {
    final rows = _db.select(
      'SELECT id FROM accounts WHERE is_primary = 1 AND is_archived = 0 LIMIT 1',
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as String;
  }

  /// Creates the primary checking account and an opening-balance transaction.
  String createPrimaryChecking(PrimaryCheckingDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Account name is required');
    }
    if (hasPrimaryAccount()) {
      throw StateError('A primary account already exists');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final openingDate = _dateOnly(draft.openingDate);
    final accountId = _uuid.v4();
    final txId = _uuid.v4();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
INSERT INTO accounts (
  id, name, type, institution, currency_code,
  is_primary, is_archived, include_in_debt_list,
  opening_balance_cents, opening_date, created_at, updated_at
) VALUES (?, ?, 'checking', ?, 'USD', 1, 0, 0, ?, ?, ?, ?)
''',
        [
          accountId,
          name,
          draft.institution?.trim().isEmpty ?? true
              ? null
              : draft.institution!.trim(),
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
          'Initial balance from setup wizard',
          draft.openingBalanceCents,
          now,
          now,
          now,
        ],
      );

      _db.execute(
        '''
INSERT INTO app_settings (key, value) VALUES ('primary_account_id', ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value
''',
        [accountId],
      );

      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }

    return accountId;
  }

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
