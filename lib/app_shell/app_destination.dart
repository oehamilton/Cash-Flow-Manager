import 'package:flutter/material.dart';

/// Top-level shell destinations (placeholder content until later phases).
enum AppDestination {
  register,
  accounts,
  debts,
  settings;

  String get label => switch (this) {
        AppDestination.register => 'Register',
        AppDestination.accounts => 'Accounts',
        AppDestination.debts => 'Debts',
        AppDestination.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        AppDestination.register => Icons.view_list_outlined,
        AppDestination.accounts => Icons.account_balance_outlined,
        AppDestination.debts => Icons.trending_down,
        AppDestination.settings => Icons.settings_outlined,
      };

  IconData get selectedIcon => switch (this) {
        AppDestination.register => Icons.view_list,
        AppDestination.accounts => Icons.account_balance,
        AppDestination.debts => Icons.trending_down,
        AppDestination.settings => Icons.settings,
      };
}
