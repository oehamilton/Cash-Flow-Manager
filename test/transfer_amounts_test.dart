import 'package:cash_flow_manager/data/account_type.dart';
import 'package:cash_flow_manager/data/transfer_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransferAmounts.counterpartAmount', () {
    test('asset to asset uses opposite signs', () {
      expect(
        TransferAmounts.counterpartAmount(
          sourceType: AccountType.checking,
          destType: AccountType.savings,
          sourceAmountCents: -5000,
        ),
        5000,
      );
      expect(
        TransferAmounts.counterpartAmount(
          sourceType: AccountType.checking,
          destType: AccountType.savings,
          sourceAmountCents: 5000,
        ),
        -5000,
      );
    });

    test('asset to debt payment uses same signs', () {
      expect(
        TransferAmounts.counterpartAmount(
          sourceType: AccountType.checking,
          destType: AccountType.creditCard,
          sourceAmountCents: -20000,
        ),
        -20000,
      );
    });

    test('debt to asset advance uses same signs', () {
      expect(
        TransferAmounts.counterpartAmount(
          sourceType: AccountType.creditCard,
          destType: AccountType.checking,
          sourceAmountCents: 15000,
        ),
        15000,
      );
    });

    test('income to asset uses opposite signs', () {
      expect(
        TransferAmounts.counterpartAmount(
          sourceType: AccountType.income,
          destType: AccountType.checking,
          sourceAmountCents: -300000,
        ),
        300000,
      );
    });
  });
}
