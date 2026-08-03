import 'recurrence_frequency.dart';
import 'recurrence_schedule.dart';

/// Persisted row in [recurrence_rules].
class RecurrenceRule {
  const RecurrenceRule({
    required this.id,
    required this.accountId,
    this.linkedAccountId,
    required this.payee,
    this.memo,
    required this.amountCents,
    required this.frequency,
    required this.interval,
    required this.anchorDate,
    this.nextScheduledDate,
    this.endDate,
    required this.autoClear,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final String? linkedAccountId;
  final String payee;
  final String? memo;
  final int amountCents;
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime anchorDate;
  final DateTime? nextScheduledDate;
  final DateTime? endDate;
  final bool autoClear;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RecurrenceRule.fromRow(Map<String, Object?> row) {
    return RecurrenceRule(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      linkedAccountId: row['linked_account_id'] as String?,
      payee: row['payee'] as String,
      memo: row['memo'] as String?,
      amountCents: row['amount_cents'] as int,
      frequency: RecurrenceFrequency.parse(row['frequency'] as String),
      interval: row['interval'] as int,
      anchorDate: RecurrenceSchedule.parseDateOnly(row['anchor_date'] as String),
      nextScheduledDate: _parseOptionalDate(row['next_scheduled_date'] as String?),
      endDate: _parseOptionalDate(row['end_date'] as String?),
      autoClear: (row['auto_clear'] as int) == 1,
      isActive: (row['is_active'] as int) == 1,
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
}

class RecurrenceRuleDraft {
  const RecurrenceRuleDraft({
    required this.accountId,
    this.linkedAccountId,
    required this.payee,
    this.memo,
    required this.amountCents,
    required this.frequency,
    this.interval = 1,
    required this.anchorDate,
    this.endDate,
    this.autoClear = false,
    this.isActive = true,
  });

  final String accountId;
  final String? linkedAccountId;
  final String payee;
  final String? memo;
  final int amountCents;
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime anchorDate;
  final DateTime? endDate;
  final bool autoClear;
  final bool isActive;
}

class RecurrenceRuleUpdate {
  const RecurrenceRuleUpdate({
    this.linkedAccountId,
    this.clearLinkedAccountId = false,
    this.payee,
    this.memo,
    this.clearMemo = false,
    this.amountCents,
    this.frequency,
    this.interval,
    this.anchorDate,
    this.endDate,
    this.clearEndDate = false,
    this.autoClear,
    this.isActive,
  });

  final String? linkedAccountId;
  final bool clearLinkedAccountId;
  final String? payee;
  final String? memo;
  final bool clearMemo;
  final int? amountCents;
  final RecurrenceFrequency? frequency;
  final int? interval;
  final DateTime? anchorDate;
  final DateTime? endDate;
  final bool clearEndDate;
  final bool? autoClear;
  final bool? isActive;
}
