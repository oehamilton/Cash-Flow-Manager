import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_history.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:cash_flow_manager/features/accounts/account_history_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  group('formatAxisCents', () {
    test('rounds to nearest \$10 with no cents', () {
      expect(formatAxisCents(5000), r'$50');
      expect(formatAxisCents(50000), r'$500');
      expect(formatAxisCents(1275), r'$10');
      expect(formatAxisCents(1749), r'$20');
      expect(formatAxisCents(-1275), r'-$10');
    });
  });

  group('AccountHistory', () {
    test('trailingMonthStarts covers 12 months ending at asOf', () {
      final months = AccountHistory.trailingMonthStarts(DateTime(2026, 7, 24));
      expect(months, hasLength(12));
      expect(months.first, DateTime(2025, 8, 1));
      expect(months.last, DateTime(2026, 7, 1));
    });

    test('monthEndCap caps current month at asOf', () {
      expect(
        AccountHistory.monthEndCap(DateTime(2026, 7, 1), DateTime(2026, 7, 15)),
        DateTime(2026, 7, 15),
      );
      expect(
        AccountHistory.monthEndCap(DateTime(2026, 6, 1), DateTime(2026, 7, 15)),
        DateTime(2026, 6, 30),
      );
    });
  });

  group('TransactionRepository.trailingTwelveMonths', () {
    final harness = TempVaultHarness();

    setUp(harness.setUp);
    tearDown(harness.tearDown);

    test('reports month-end balance and interest paid', () async {
      await harness.createUnlockedVault();
      final accounts = AccountRepository(harness.session);
      accounts.createPrimaryChecking(
        PrimaryCheckingDraft(
          name: 'Checking',
          openingBalanceCents: 0,
          openingDate: DateTime(2025, 1, 1),
        ),
      );
      final cardId = accounts.create(
        AccountDraft(
          name: 'Card',
          type: AccountType.creditCard,
          openingBalanceCents: 100000,
          openingDate: DateTime(2026, 1, 1),
        ),
      );
      final txs = TransactionRepository(harness.session);
      txs.create(
        TransactionDraft(
          accountId: cardId,
          date: DateTime(2026, 6, 10),
          payee: 'Interest',
          amountCents: 4500,
          interestCents: 4500,
        ),
        asOf: DateTime(2026, 7, 15),
      );
      txs.create(
        TransactionDraft(
          accountId: cardId,
          date: DateTime(2026, 7, 5),
          payee: 'Payment',
          amountCents: -20000,
          interestCents: 2000,
          principalCents: 18000,
        ),
        asOf: DateTime(2026, 7, 15),
      );

      final series = txs.trailingTwelveMonths(
        cardId,
        asOf: DateTime(2026, 7, 15),
      );
      expect(series, hasLength(12));
      expect(series.last.monthKey, '2026-07');
      expect(series.last.interestPaidCents, 2000);
      // Opening 100000 + June interest +4500 + July payment -20000
      expect(series.last.balanceCents, 84500);

      final june = series.firstWhere((p) => p.monthKey == '2026-06');
      expect(june.interestPaidCents, 4500);
      expect(june.balanceCents, 104500);
    });
  });
}
