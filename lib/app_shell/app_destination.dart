import 'package:flutter/material.dart';

/// Top-level shell destinations.
enum AppDestination {
  register,
  accounts,
  debts,
  payees,
  settings;

  String get label => switch (this) {
        AppDestination.register => 'Register',
        AppDestination.accounts => 'Accounts',
        AppDestination.debts => 'Debts',
        AppDestination.payees => 'Payees',
        AppDestination.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        AppDestination.register => Icons.view_list_outlined,
        AppDestination.accounts => Icons.account_balance_outlined,
        AppDestination.debts => Icons.trending_down,
        AppDestination.payees => Icons.people_outline,
        AppDestination.settings => Icons.settings_outlined,
      };

  IconData get selectedIcon => switch (this) {
        AppDestination.register => Icons.view_list,
        AppDestination.accounts => Icons.account_balance,
        AppDestination.debts => Icons.trending_down,
        AppDestination.payees => Icons.people,
        AppDestination.settings => Icons.settings,
      };
}
