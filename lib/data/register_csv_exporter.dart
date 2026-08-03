import 'recurrence_schedule.dart';
import 'transaction.dart';

/// Builds CSV text for a register export (Phase 5.2).
abstract final class RegisterCsvExporter {
  static String suggestedFileName(String accountName, {DateTime? asOf}) {
    final day = asOf ?? DateTime.now();
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    final safe = accountName
        .trim()
        .replaceAll(RegExp(r'[^\w\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final label = safe.isEmpty ? 'register' : safe;
    return '$label-register-$y$m$d.csv';
  }

  static String export(Iterable<RegisterEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln(
      'date,payee,memo,amount,debit,credit,'
      'running_balance,cleared,source,interest,principal,id',
    );
    for (final entry in entries) {
      final tx = entry.transaction;
      buffer.writeln(
        [
          _cell(RecurrenceSchedule.formatDate(tx.date)),
          _cell(tx.payee ?? ''),
          _cell(tx.memo ?? ''),
          _cell(_dollars(tx.amountCents)),
          _cell(entry.debitCents == null ? '' : _dollars(entry.debitCents!)),
          _cell(entry.creditCents == null ? '' : _dollars(entry.creditCents!)),
          _cell(_dollars(entry.runningBalanceCents)),
          _cell(tx.isCleared ? '1' : '0'),
          _cell(tx.source),
          _cell(tx.interestCents == null ? '' : _dollars(tx.interestCents!)),
          _cell(tx.principalCents == null ? '' : _dollars(tx.principalCents!)),
          _cell(tx.id),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  /// Spreadsheet-friendly dollars with two decimals (no currency symbol).
  static String _dollars(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final rem = (abs % 100).toString().padLeft(2, '0');
    return '$sign$dollars.$rem';
  }

  static String _cell(String value) {
    if (value.contains('"') ||
        value.contains(',') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
