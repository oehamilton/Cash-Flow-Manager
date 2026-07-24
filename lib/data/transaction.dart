/// Persisted ledger row in [transactions].
class Transaction {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.date,
    this.postDate,
    this.payee,
    this.memo,
    required this.amountCents,
    required this.isCleared,
    this.clearedAt,
    required this.source,
    this.recurrenceRuleId,
    this.recurrenceInstanceKey,
    required this.isUserOverridden,
    this.transferPairId,
    this.interestCents,
    this.principalCents,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final DateTime date;
  final DateTime? postDate;
  final String? payee;
  final String? memo;
  final int amountCents;
  final bool isCleared;
  final DateTime? clearedAt;
  final String source;
  final String? recurrenceRuleId;
  final String? recurrenceInstanceKey;
  final bool isUserOverridden;
  final String? transferPairId;
  final int? interestCents;
  final int? principalCents;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpeningBalance => source == TransactionSource.openingBalance;

  factory Transaction.fromRow(Map<String, Object?> row) {
    return Transaction(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      date: DateTime.parse(row['date'] as String),
      postDate: _parseOptionalDate(row['post_date'] as String?),
      payee: row['payee'] as String?,
      memo: row['memo'] as String?,
      amountCents: row['amount_cents'] as int,
      isCleared: (row['is_cleared'] as int) == 1,
      clearedAt: _parseOptionalDateTime(row['cleared_at'] as String?),
      source: row['source'] as String,
      recurrenceRuleId: row['recurrence_rule_id'] as String?,
      recurrenceInstanceKey: row['recurrence_instance_key'] as String?,
      isUserOverridden: (row['is_user_overridden'] as int) == 1,
      transferPairId: row['transfer_pair_id'] as String?,
      interestCents: row['interest_cents'] as int?,
      principalCents: row['principal_cents'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  static DateTime? _parseOptionalDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.parse(raw);
  }

  static DateTime? _parseOptionalDateTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.parse(raw);
  }
}

/// Known [Transaction.source] values.
abstract final class TransactionSource {
  static const manual = 'manual';
  static const recurringGenerated = 'recurring_generated';
  static const manualFuture = 'manual_future';
  static const openingBalance = 'opening_balance';
}

/// Ledger row with computed running balance (Phase 2.2).
class RegisterEntry {
  const RegisterEntry({
    required this.transaction,
    required this.runningBalanceCents,
  });

  final Transaction transaction;
  final int runningBalanceCents;

  /// Inflow amount for Credit column (null when not a credit).
  int? get creditCents {
    final amount = transaction.amountCents;
    return amount > 0 ? amount : null;
  }

  /// Outflow amount for Debit column (positive display cents; null when none).
  int? get debitCents {
    final amount = transaction.amountCents;
    return amount < 0 ? -amount : null;
  }
}

/// Walks chronological transactions and attaches a running balance after each.
List<RegisterEntry> withRunningBalances(Iterable<Transaction> transactions) {
  var running = 0;
  final entries = <RegisterEntry>[];
  for (final tx in transactions) {
    running += tx.amountCents;
    entries.add(
      RegisterEntry(transaction: tx, runningBalanceCents: running),
    );
  }
  return entries;
}

/// Fields required to create a user-entered transaction (Phase 2.1).
class TransactionDraft {
  const TransactionDraft({
    required this.accountId,
    required this.date,
    this.payee,
    this.memo,
    required this.amountCents,
  });

  final String accountId;
  final DateTime date;
  final String? payee;
  final String? memo;
  final int amountCents;
}

/// Patchable transaction fields for updates.
class TransactionUpdate {
  const TransactionUpdate({
    this.date,
    this.payee,
    this.clearPayee = false,
    this.memo,
    this.clearMemo = false,
    this.amountCents,
  });

  final DateTime? date;
  final String? payee;
  final bool clearPayee;
  final String? memo;
  final bool clearMemo;
  final int? amountCents;
}
