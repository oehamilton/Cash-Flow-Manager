import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../core/app_info.dart';
import '../data/account_repository.dart';
import '../features/accounts/accounts_page.dart';
import '../features/accounts/debts_page.dart';
import '../features/register/register_page.dart';
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
    this.initialRegisterAccountId,
  });

  final AppDestination initialDestination;
  final AuthService? auth;
  final Future<void> Function()? onLock;
  final bool helloEnabled;
  final bool helloAvailable;
  final Future<void> Function(bool enable)? onToggleHello;

  /// Optional override for tests; otherwise cold start uses primary.
  final String? initialRegisterAccountId;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination;
  String? _registerAccountId;
  String? _databasePath;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    _registerAccountId = widget.initialRegisterAccountId;
    _loadAccountContext();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth?.session != widget.auth?.session) {
      _registerAccountId = widget.initialRegisterAccountId;
      _loadAccountContext();
    }
  }

  Future<void> _loadAccountContext() async {
    final auth = widget.auth;
    String? path;
    String? registerId = _registerAccountId;
    if (auth?.session != null) {
      final repo = AccountRepository(auth!.session!);
      final primaryId = repo.primaryAccountId();
      registerId ??= primaryId;
      if (registerId != null && repo.getById(registerId) == null) {
        registerId = primaryId;
      }
      path = await auth.databasePath();
    } else {
      registerId = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _registerAccountId = registerId;
      _databasePath = path;
    });
  }

  void _openRegister(String accountId) {
    setState(() {
      _registerAccountId = accountId;
      _destination = AppDestination.register;
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
                // Rail → Register keeps the current account, or falls back
                // to primary on first open / missing account.
                if (_destination == AppDestination.register &&
                    widget.auth?.session != null) {
                  final repo = AccountRepository(widget.auth!.session!);
                  if (_registerAccountId == null ||
                      repo.getById(_registerAccountId!) == null) {
                    _registerAccountId = repo.primaryAccountId();
                  }
                }
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
      AppDestination.register => RegisterPage(
          key: Key('register_${_registerAccountId ?? 'none'}'),
          auth: widget.auth,
          accountId: _registerAccountId,
        ),
      AppDestination.accounts => AccountsPage(
          key: const Key('page_accounts'),
          auth: widget.auth,
          onOpenRegister: _openRegister,
        ),
      AppDestination.debts => DebtsPage(
          key: const Key('page_debts'),
          auth: widget.auth,
          onOpenRegister: _openRegister,
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
