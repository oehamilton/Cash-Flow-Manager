/// Account kinds stored in [accounts.type].
enum AccountType {
  checking,
  savings,
  income,
  loan,
  creditCard,
  utility,
  other;

  String get dbValue => switch (this) {
        AccountType.checking => 'checking',
        AccountType.savings => 'savings',
        AccountType.income => 'income',
        AccountType.loan => 'loan',
        AccountType.creditCard => 'credit_card',
        AccountType.utility => 'utility',
        AccountType.other => 'other',
      };

  String get label => switch (this) {
        AccountType.checking => 'Checking',
        AccountType.savings => 'Savings',
        AccountType.income => 'Income',
        AccountType.loan => 'Loan',
        AccountType.creditCard => 'Credit card',
        AccountType.utility => 'Utility',
        AccountType.other => 'Other',
      };

  /// Debt-list default for new accounts of this type.
  bool get defaultIncludeInDebtList =>
      this == AccountType.loan || this == AccountType.creditCard;

  /// Show optional interest/principal split fields on register txs (Phase 4.1).
  bool get showsInterestPrincipal =>
      this == AccountType.loan || this == AccountType.creditCard;

  static AccountType parse(String value) {
    return AccountType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => throw FormatException('Unknown account type: $value'),
    );
  }
}
