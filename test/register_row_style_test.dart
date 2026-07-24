import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/features/register/register_row_style.dart';
import 'package:cash_flow_manager/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asOf = DateTime(2026, 7, 15);

  Transaction tx({
    required bool cleared,
    required DateTime date,
    String source = TransactionSource.manual,
  }) {
    final now = DateTime.utc(2026, 7, 1);
    return Transaction(
      id: 't',
      accountId: 'a',
      date: date,
      amountCents: -100,
      isCleared: cleared,
      source: source,
      isUserOverridden: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('cleared rows use cleared background and muted foreground', () {
    final style = RegisterRowStyle.forTransaction(
      tx(cleared: true, date: DateTime(2026, 7, 1)),
      asOf: asOf,
    );
    expect(style.background, AppColors.rowCleared);
    expect(style.accent, AppColors.primary);
    expect(style.mutedForeground, isTrue);
    expect(style.kind, RegisterRowKind.cleared);
  });

  test('uncleared past rows use uncleared-past background', () {
    final style = RegisterRowStyle.forTransaction(
      tx(cleared: false, date: DateTime(2026, 7, 10)),
      asOf: asOf,
    );
    expect(style.background, AppColors.rowUnclearedPast);
    expect(style.accent, AppColors.danger);
    expect(style.kind, RegisterRowKind.unclearedPast);
  });

  test('uncleared future manual rows use manual-future background', () {
    final style = RegisterRowStyle.forTransaction(
      tx(
        cleared: false,
        date: DateTime(2026, 8, 1),
        source: TransactionSource.manualFuture,
      ),
      asOf: asOf,
    );
    expect(style.background, AppColors.rowManualFuture);
    expect(style.accent, AppColors.warning);
    expect(style.kind, RegisterRowKind.manualFuture);
  });

  test('uncleared future generated rows use auto-future background', () {
    final style = RegisterRowStyle.forTransaction(
      tx(
        cleared: false,
        date: DateTime(2026, 8, 1),
        source: TransactionSource.recurringGenerated,
      ),
      asOf: asOf,
    );
    expect(style.background, AppColors.rowAutoFuture);
    expect(style.accent, AppColors.primaryBright);
    expect(style.kind, RegisterRowKind.autoFuture);
  });

  test('cleared wins over future date', () {
    final style = RegisterRowStyle.forTransaction(
      tx(cleared: true, date: DateTime(2026, 8, 1)),
      asOf: asOf,
    );
    expect(style.background, AppColors.rowCleared);
    expect(style.kind, RegisterRowKind.cleared);
  });
}
