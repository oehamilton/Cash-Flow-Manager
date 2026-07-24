import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../core/app_info.dart';
import '../data/account_repository.dart';
import '../features/placeholders/placeholder_page.dart';
import '../features/settings/settings_page.dart';
import '../theme/app_colors.dart';
import 'app_destination.dart';

/// Desktop shell: left rail navigation + destination content.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialDestination = AppDestination.register,
    this.auth,
    this.onLock,
    this.helloEnabled = false,
    this.helloAvailable = false,
    this.onToggleHello,
  });

  final AppDestination initialDestination;
  final AuthService? auth;
  final Future<void> Function()? onLock;
  final bool helloEnabled;
  final bool helloAvailable;
  final Future<void> Function(bool enable)? onToggleHello;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination = widget.initialDestination;
  String? _primaryName;
  String? _databasePath;

  @override
  void initState() {
    super.initState();
    _loadAccountContext();
  }

  Future<void> _loadAccountContext() async {
    final auth = widget.auth;
    String? name;
    String? path;
    if (auth?.session != null) {
      final repo = AccountRepository(auth!.session!);
      final id = repo.primaryAccountId();
      if (id != null) {
        final rows = auth.session!.database.select(
          'SELECT name FROM accounts WHERE id = ?',
          [id],
        );
        if (rows.isNotEmpty) {
          name = rows.first['name'] as String;
        }
      }
      path = await auth.databasePath();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _primaryName = name;
      _databasePath = path;
    });
  }

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
      AppDestination.register => PlaceholderPage(
          key: const Key('page_register'),
          title: _primaryName == null
              ? 'Register'
              : 'Register — $_primaryName',
          subtitle: _primaryName == null
              ? 'Primary checking register opens here by default. Full ledger arrives in Phase 2.'
              : 'Primary checking “$_primaryName” is ready. Transaction entry arrives in Phase 2.',
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
      AppDestination.settings => SettingsPage(
          key: const Key('page_settings'),
          helloEnabled: widget.helloEnabled,
          helloAvailable: widget.helloAvailable,
          databasePath: _databasePath,
          onLock: widget.onLock ?? () async {},
          onToggleHello: widget.onToggleHello ?? (_) async {},
        ),
    };
  }
}
