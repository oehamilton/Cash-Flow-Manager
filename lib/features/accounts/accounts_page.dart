import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'add_account_dialog.dart';

/// All non-archived accounts with running balance (Phase 1.2).
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.auth});

  final AuthService? auth;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<AccountSummary> _rows = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  @override
  void didUpdateWidget(covariant AccountsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth?.session != widget.auth?.session) {
      _reload();
    }
  }

  void _reload({bool initial = false}) {
    final session = widget.auth?.session;
    List<AccountSummary> rows = const [];
    String? error;
    if (session == null) {
      rows = const [];
    } else {
      try {
        rows = AccountRepository(session).listSummaries();
      } on Object catch (e) {
        error = e.toString();
      }
    }
    if (initial) {
      _rows = rows;
      _error = error;
      _loading = false;
      return;
    }
    setState(() {
      _rows = rows;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _addAccount() async {
    final session = widget.auth?.session;
    if (session == null) {
      return;
    }
    final draft = await AddAccountDialog.show(context);
    if (draft == null || !mounted) {
      return;
    }
    try {
      AccountRepository(session).create(draft);
      _reload();
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundDeep,
            AppColors.backgroundMid,
            Color(0xFF0C3338),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Accounts',
                    key: const Key('accounts_title'),
                    style: textTheme.headlineMedium,
                  ),
                ),
                FilledButton.icon(
                  key: const Key('accounts_add_button'),
                  onPressed: widget.auth?.session == null ? null : _addAccount,
                  icon: const Icon(Icons.add),
                  label: const Text('Add account'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Every account has a full register. Primary checking is marked below. '
              'Account detail arrives in Phase 1.3.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_rows.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    widget.auth?.session == null
                        ? 'Unlock a vault to manage accounts.'
                        : 'No accounts yet. Add your first account.',
                    key: const Key('accounts_empty'),
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    _header(textTheme),
                    const Divider(height: 1, color: AppColors.outline),
                    Expanded(
                      child: ListView.separated(
                        key: const Key('accounts_list'),
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.outline,
                        ),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return _AccountRow(summary: row);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(TextTheme textTheme) {
    final style = textTheme.labelLarge?.copyWith(
      color: AppColors.onSurfaceMuted,
      fontFamily: AppTheme.monoFont,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(flex: 2, child: Text('Type', style: style)),
          Expanded(
            flex: 2,
            child: Text('Balance', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.summary});

  final AccountSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final account = summary.account;
    final balanceColor = summary.balanceCents < 0
        ? AppColors.danger
        : AppColors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    account.name,
                    key: Key('account_row_${account.id}'),
                    style: textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (account.isPrimary) ...[
                  const SizedBox(width: 8),
                  Text(
                    'PRIMARY',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryBright,
                      fontFamily: AppTheme.monoFont,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              account.type.label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCents(summary.balanceCents),
              textAlign: TextAlign.end,
              style: textTheme.titleMedium?.copyWith(
                fontFamily: AppTheme.monoFont,
                color: balanceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
