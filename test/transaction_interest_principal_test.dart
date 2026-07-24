import 'package:cash_flow_manager/data/account.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/transaction.dart';
import 'package:cash_flow_manager/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('loan/credit card types show interest-principal fields', () {
    expect(AccountType.loan.showsInterestPrincipal, isTrue);
    expect(AccountType.creditCard.showsInterestPrincipal, isTrue);
    expect(AccountType.checking.showsInterestPrincipal, isFalse);
  });

  test('validateInterestPrincipalSplit rejects over-amount tags', () {
    expect(
      () => validateInterestPrincipalSplit(
        amountCents: -10000,
        interestCents: 6000,
        principalCents: 5000,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('create/update persist interest and principal on debt account', () async {
    await harness.createUnlockedVault();
    final accounts = AccountRepository(harness.session);
    accounts.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final cardId = accounts.create(
      AccountDraft(
        name: 'Visa',
        type: AccountType.creditCard,
        openingBalanceCents: -50000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );
    final txs = TransactionRepository(harness.session);
    final id = txs.create(
      TransactionDraft(
        accountId: cardId,
        date: DateTime(2026, 7, 15),
        payee: 'Payment',
        amountCents: -20000,
        interestCents: 3500,
        principalCents: 16500,
      ),
    );

    final created = txs.getById(id)!;
    expect(created.interestCents, 3500);
    expect(created.principalCents, 16500);

    txs.update(
      id,
      const TransactionUpdate(
        interestCents: 4000,
        principalCents: 16000,
      ),
    );
    expect(txs.getById(id)!.interestCents, 4000);
    expect(txs.getById(id)!.principalCents, 16000);

    txs.update(
      id,
      const TransactionUpdate(clearInterest: true, clearPrincipal: true),
    );
    expect(txs.getById(id)!.interestCents, isNull);
    expect(txs.getById(id)!.principalCents, isNull);
  });
}
