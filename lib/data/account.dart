import 'account_type.dart';

/// Persisted account row.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.institution,
    this.accountNumber,
    this.loginUrl,
    this.loginUsername,
    this.loginPassword,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.notes,
    this.interestRateApr,
    this.minimumPaymentCents,
    this.paymentDueDay,
    this.currencyCode = 'USD',
    required this.isPrimary,
    required this.isArchived,
    required this.includeInDebtList,
    this.minBalanceCents = 0,
    required this.openingBalanceCents,
    required this.openingDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String? institution;
  final String? accountNumber;
  final String? loginUrl;
  final String? loginUsername;
  final String? loginPassword;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? notes;
  final double? interestRateApr;
  final int? minimumPaymentCents;
  final int? paymentDueDay;
  final String currencyCode;
  final bool isPrimary;
  final bool isArchived;
  final bool includeInDebtList;

  /// Soft floor for checking registers (extra-payment surplus + warnings).
  final int minBalanceCents;
  final int openingBalanceCents;
  final DateTime openingDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Account.fromRow(Map<String, Object?> row) {
    return Account(
      id: row['id'] as String,
      name: row['name'] as String,
      type: AccountType.parse(row['type'] as String),
      institution: row['institution'] as String?,
      accountNumber: row['account_number'] as String?,
      loginUrl: row['login_url'] as String?,
      loginUsername: row['login_username'] as String?,
      loginPassword: row['login_password'] as String?,
      contactName: row['contact_name'] as String?,
      contactPhone: row['contact_phone'] as String?,
      contactEmail: row['contact_email'] as String?,
      notes: row['notes'] as String?,
      interestRateApr: (row['interest_rate_apr'] as num?)?.toDouble(),
      minimumPaymentCents: row['minimum_payment_cents'] as int?,
      paymentDueDay: row['payment_due_day'] as int?,
      currencyCode: row['currency_code'] as String? ?? 'USD',
      isPrimary: (row['is_primary'] as int) == 1,
      isArchived: (row['is_archived'] as int) == 1,
      includeInDebtList: (row['include_in_debt_list'] as int) == 1,
      minBalanceCents: row['min_balance_cents'] as int? ?? 0,
      openingBalanceCents: row['opening_balance_cents'] as int,
      openingDate: DateTime.parse(row['opening_date'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

/// Account plus computed register balance for list views.
class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.balanceCents,
  });

  final Account account;
  final int balanceCents;
}

/// Fields required to create an account (Phase 1.1).
class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    this.institution,
    this.accountNumber,
    this.loginUrl,
    this.loginUsername,
    this.loginPassword,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.notes,
    this.interestRateApr,
    this.minimumPaymentCents,
    this.paymentDueDay,
    this.currencyCode = 'USD',
    this.isPrimary = false,
    this.includeInDebtList,
    this.minBalanceCents = 0,
    required this.openingBalanceCents,
    required this.openingDate,
  });

  final String name;
  final AccountType type;
  final String? institution;
  final String? accountNumber;
  final String? loginUrl;
  final String? loginUsername;
  final String? loginPassword;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? notes;
  final double? interestRateApr;
  final int? minimumPaymentCents;
  final int? paymentDueDay;
  final String currencyCode;
  final bool isPrimary;
  final bool? includeInDebtList;
  final int minBalanceCents;
  final int openingBalanceCents;
  final DateTime openingDate;
}

/// Patchable account fields for updates.
class AccountUpdate {
  const AccountUpdate({
    this.name,
    this.type,
    this.institution,
    this.accountNumber,
    this.loginUrl,
    this.loginUsername,
    this.loginPassword,
    this.clearLoginPassword = false,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.notes,
    this.interestRateApr,
    this.clearInterestRateApr = false,
    this.minimumPaymentCents,
    this.clearMinimumPaymentCents = false,
    this.paymentDueDay,
    this.clearPaymentDueDay = false,
    this.currencyCode,
    this.includeInDebtList,
    this.minBalanceCents,
  });

  final String? name;
  final AccountType? type;
  final String? institution;
  final String? accountNumber;
  final String? loginUrl;
  final String? loginUsername;
  final String? loginPassword;
  final bool clearLoginPassword;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? notes;
  final double? interestRateApr;
  final bool clearInterestRateApr;
  final int? minimumPaymentCents;
  final bool clearMinimumPaymentCents;
  final int? paymentDueDay;
  final bool clearPaymentDueDay;
  final String? currencyCode;
  final bool? includeInDebtList;
  final int? minBalanceCents;
}
