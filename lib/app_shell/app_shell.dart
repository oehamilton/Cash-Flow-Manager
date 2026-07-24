import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../features/placeholders/placeholder_page.dart';
import '../theme/app_colors.dart';
import 'app_destination.dart';

/// Desktop shell: left rail navigation + destination content.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialDestination = AppDestination.register,
  });

  final AppDestination initialDestination;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination = widget.initialDestination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            key: const Key('app_nav_rail'),
            selectedIndex: _destination.index,
            onDestinationSelected: (index) {
              setState(() {
                _destination = AppDestination.values[index];
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
              child: Column(
                children: [
                  Text(
                    'CFM',
                    key: const Key('app_shell_brand'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primaryBright,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppInfo.versionLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final dest in AppDestination.values)
                NavigationRailDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon),
                  label: Text(dest.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: KeyedSubtree(
              key: Key('destination_${_destination.name}'),
              child: _pageFor(_destination),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageFor(AppDestination destination) {
    return switch (destination) {
      AppDestination.register => const PlaceholderPage(
          key: Key('page_register'),
          title: 'Register',
          subtitle:
              'Primary checking register opens here by default. Full ledger arrives in Phase 2.',
          phaseHint: '// phase 2 — transactions, clear, running balance',
        ),
      AppDestination.accounts => const PlaceholderPage(
          key: Key('page_accounts'),
          title: 'Accounts',
          subtitle:
              'Manage checking, income, and debt accounts. CRUD arrives in Phase 1.',
          phaseHint: '// phase 1 — account list and detail',
        ),
      AppDestination.debts => const PlaceholderPage(
          key: Key('page_debts'),
          title: 'Debts',
          subtitle:
              'Balances, APR, and payments at a glance. List view arrives in Phase 1.',
          phaseHint: '// phase 1.2 — debt list',
        ),
      AppDestination.settings => const PlaceholderPage(
          key: Key('page_settings'),
          title: 'Settings',
          subtitle:
              'Encrypted DB layer is ready (Phase 0.3). Path picker, unlock UI, '
              'and horizon settings wire up next.',
          phaseHint: '// phase 0.4–0.5 — unlock, wizard, db path UI',
        ),
    };
  }
}
