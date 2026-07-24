import 'account.dart';
import 'payee.dart';

/// Autocomplete entry for the transaction / recurrence editors (Phase 6).
sealed class PayeeSuggestion {
  const PayeeSuggestion();

  String get label;
}

/// Transfer target: selecting this creates a linked pair.
class AccountPayeeSuggestion extends PayeeSuggestion {
  const AccountPayeeSuggestion(this.account);

  final Account account;

  @override
  String get label => '→ ${account.name}';

  String get accountId => account.id;
}

/// Managed directory payee (Phase 6.2).
class ManagedPayeeSuggestion extends PayeeSuggestion {
  const ManagedPayeeSuggestion(this.payee);

  final Payee payee;

  @override
  String get label => payee.name;

  String get payeeId => payee.id;
}

/// Historical free-text payee.
class TextPayeeSuggestion extends PayeeSuggestion {
  const TextPayeeSuggestion(this.name);

  final String name;

  @override
  String get label => name;
}
