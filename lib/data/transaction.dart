import 'recurrence_schedule.dart';

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
    this.payeeId,
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
  final String? payeeId;
  final int? interestCents;
  final int? principalCents;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpeningBalance => source == TransactionSource.openingBalance;

  bool get isRecurringGenerated =>
      source == TransactionSource.recurringGenerated;

  bool get isTransfer => transferPairId != null;

  factory Transaction.fromRow(Map<String, Object?> row) {
    return Transaction(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      date: RecurrenceSchedule.parseDateOnly(row['date'] as String),
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
      payeeId: row['payee_id'] as String?,
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
    return RecurrenceSchedule.parseDateOnly(raw);
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

  /// Manual entry source based on whether [date] is after [asOf] (today).
  static String manualForDate(DateTime date, {DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final txDate = DateTime(date.year, date.month, date.day);
    return txDate.isAfter(todayDate) ? manualFuture : manual;
  }

  /// Whether [source] is a user-entered manual row (past or future).
  static bool isUserManual(String source) =>
      source == manual || source == manualFuture;
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

/// Sticky register header metrics (Phase 2.4 / 3.5).
///
/// Troughs are the lowest projected running balance in the next 4 / 8 weeks.
class RegisterMetrics {
  const RegisterMetrics({
    required this.reconciledCents,
    required this.todayCents,
    this.trough4WeeksCents,
    this.trough8WeeksCents,
  });

  final int reconciledCents;
  final int todayCents;
  final int? trough4WeeksCents;
  final int? trough8WeeksCents;
}

/// Fields required to create a user-entered transaction (Phase 2.1 / 6.1).
class TransactionDraft {
  const TransactionDraft({
    required this.accountId,
    required this.date,
    this.payee,
    this.payeeId,
    this.transferToAccountId,
    this.memo,
    required this.amountCents,
    this.interestCents,
    this.principalCents,
  });

  final String accountId;
  final DateTime date;
  final String? payee;
  final String? payeeId;

  /// When set, creates a linked transfer leg on this account.
  final String? transferToAccountId;
  final String? memo;
  final int amountCents;
  final int? interestCents;
  final int? principalCents;
}

/// Patchable transaction fields for updates.
class TransactionUpdate {
  const TransactionUpdate({
    this.date,
    this.payee,
    this.clearPayee = false,
    this.payeeId,
    this.clearPayeeId = false,
    this.transferToAccountId,
    this.clearTransfer = false,
    this.memo,
    this.clearMemo = false,
    this.amountCents,
    this.interestCents,
    this.clearInterest = false,
    this.principalCents,
    this.clearPrincipal = false,
  });

  final DateTime? date;
  final String? payee;
  final bool clearPayee;
  final String? payeeId;
  final bool clearPayeeId;

  /// Set to link/retarget a transfer; use [clearTransfer] to drop the pair.
  final String? transferToAccountId;
  final bool clearTransfer;
  final String? memo;
  final bool clearMemo;
  final int? amountCents;
  final int? interestCents;
  final bool clearInterest;
  final int? principalCents;
  final bool clearPrincipal;
}

/// Validates optional interest/principal tags against [amountCents].
void validateInterestPrincipalSplit({
  required int amountCents,
  int? interestCents,
  int? principalCents,
}) {
  if (interestCents != null && interestCents < 0) {
    throw ArgumentError('Interest must be ≥ 0');
  }
  if (principalCents != null && principalCents < 0) {
    throw ArgumentError('Principal must be ≥ 0');
  }
  final interest = interestCents ?? 0;
  final principal = principalCents ?? 0;
  if (interest == 0 && principal == 0 && interestCents == null && principalCents == null) {
    return;
  }
  final absAmount = amountCents.abs();
  if (interest + principal > absAmount) {
    throw ArgumentError(
      'Interest + principal cannot exceed the transaction amount',
    );
  }
}
