import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/money.dart';
import '../../data/recurrence_materializer.dart';
import '../../data/transaction.dart';
import '../../data/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../recurrence/recurrence_page.dart';
import 'reconcile_dialog.dart';
import 'register_filter.dart';
import 'register_filter_bar.dart';
import 'register_metrics_bar.dart';
import 'register_row_legend.dart';
import 'register_row_style.dart';
import 'transaction_editor_dialog.dart';

/// Register surface: sticky metrics, filter bar, and ledger.
///
/// Ledger rows are always read from [accountId] during [build] so switching
/// accounts cannot show a stale list from a previous register.
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.auth,
    required this.accountId,
  });

  final AuthService? auth;
  final String? accountId;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String? _error;
  RegisterFilter _filter = const RegisterFilter();
  final FocusNode _searchFocus = FocusNode();
  bool _showRecurring = false;
  String? _lastMaterializedAccountId;

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _materializeIfNeeded(String accountId) {
    final session = widget.auth?.session;
    if (session == null || _lastMaterializedAccountId == accountId) {
      return;
    }
    // Avoid writing the DB / mutating state synchronously during build.
    _lastMaterializedAccountId = accountId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.auth?.session == null) {
        return;
      }
      if (_lastMaterializedAccountId != accountId) {
        return;
      }
      try {
        RecurrenceMaterializer(widget.auth!.session!).materializeAccount(
          accountId,
        );
        if (mounted) {
          setState(() {});
        }
      } on Object catch (e) {
        _lastMaterializedAccountId = null;
        if (mounted) {
          setState(() => _error = e.toString());
        }
      }
    });
  }

  TransactionRepository? get _transactions {
    final session = widget.auth?.session;
    if (session == null) {
      return null;
    }
    return TransactionRepository(session);
  }

  Future<void> _addTransaction(Account account) async {
    final repo = _transactions;
    if (repo == null) {
      return;
    }
    final result = await TransactionEditorDialog.show(
      context,
      suggestions: repo.payeeSuggestions(account.id),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      repo.create(
        TransactionDraft(
          accountId: account.id,
          date: result.date,
          payee: result.payee,
          memo: result.memo,
          amountCents: result.amountCents,
        ),
      );
      _lastMaterializedAccountId = null;
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _editTransaction(Transaction tx) async {
    if (tx.isOpeningBalance || tx.isCleared) {
      return;
    }
    final repo = _transactions;
    if (repo == null) {
      return;
    }
    final result = await TransactionEditorDialog.show(
      context,
      suggestions: repo.payeeSuggestions(tx.accountId),
      initial: tx,
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      repo.update(
        tx.id,
        TransactionUpdate(
          date: result.date,
          payee: result.payee,
          clearPayee: result.payee == null || result.payee!.trim().isEmpty,
          memo: result.memo,
          clearMemo: result.memo == null || result.memo!.trim().isEmpty,
          amountCents: result.amountCents,
        ),
      );
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteTransaction(Transaction tx) async {
    if (tx.isOpeningBalance || tx.isCleared) {
      return;
    }
    final repo = _transactions;
    if (repo == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete transaction?'),
        content: Text(
          tx.payee == null || tx.payee!.isEmpty
              ? 'Delete this ${formatCents(tx.amountCents)} entry?'
              : 'Delete "${tx.payee}" (${formatCents(tx.amountCents)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('tx_confirm_delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      repo.delete(tx.id);
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _toggleCleared(Transaction tx, bool cleared) {
    final repo = _transactions;
    if (repo == null) {
      return;
    }
    try {
      repo.setCleared(tx.id, cleared: cleared);
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _openReconcile(Account account) async {
    final repo = _transactions;
    if (repo == null) {
      return;
    }
    final finished = await ReconcileDialog.show(
      context,
      accountId: account.id,
      repository: repo,
      clearedBalanceCents: repo.clearedBalanceCents(account.id),
    );
    if (!mounted) {
      return;
    }
    if (finished == true) {
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconcile finished')),
      );
    } else {
      // Cleared flags may have changed while the dialog was open.
      setState(() {});
    }
  }

  String _dateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = widget.auth?.session;
    final accountId = widget.accountId;
    final auth = widget.auth;

    if (_showRecurring &&
        auth != null &&
        session != null &&
        accountId != null) {
      return RecurrencePage(
        auth: auth,
        accountId: accountId,
        onClose: () => setState(() {
          _showRecurring = false;
          _lastMaterializedAccountId = null;
        }),
      );
    }

    Account? account;
    RegisterMetrics? metrics;
    List<RegisterEntry> entries = const [];
    List<RegisterEntry> visible = const [];
    String? loadError = _error;

    if (session != null && accountId != null) {
      try {
        final accounts = AccountRepository(session);
        final txs = TransactionRepository(session);
        account = accounts.getById(accountId);
        if (account != null) {
          _materializeIfNeeded(accountId);
          metrics = txs.metricsFor(accountId);
          entries = txs.listRegisterEntries(accountId);
          visible = applyRegisterFilter(entries, _filter);
        }
      } on Object catch (e) {
        loadError = e.toString();
      }
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _AddTransactionIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ClearFilterIntent(),
      },
      child: Actions(
        actions: {
          _AddTransactionIntent: CallbackAction<_AddTransactionIntent>(
            onInvoke: (_) {
              final current = account;
              if (current != null) {
                _addTransaction(current);
              }
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              return null;
            },
          ),
          _ClearFilterIntent: CallbackAction<_ClearFilterIntent>(
            onInvoke: (_) {
              if (_filter.isActive) {
                setState(() => _filter = const RegisterFilter());
              } else if (_searchFocus.hasFocus) {
                _searchFocus.unfocus();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: DecoratedBox(
            key: const Key('page_register'),
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account == null
                              ? 'Register'
                              : 'Register — ${account.name}',
                          key: const Key('register_title'),
                          style: textTheme.headlineMedium,
                        ),
                      ),
                      if (account != null) ...[
                        OutlinedButton.icon(
                          key: const Key('register_recurring'),
                          onPressed: () =>
                              setState(() => _showRecurring = true),
                          icon: const Icon(Icons.repeat),
                          label: const Text('Recurring'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: const Key('register_reconcile'),
                          onPressed: () => _openReconcile(account!),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Reconcile'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          key: const Key('register_add_tx'),
                          onPressed: () => _addTransaction(account!),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (account == null)
                    Text(
                      session == null
                          ? 'Unlock a vault to open a register.'
                          : 'No account selected. Cold start opens primary checking when available.',
                      key: const Key('register_empty'),
                      style: textTheme.bodyLarge,
                    )
                  else ...[
                    Text(
                      '${account.type.label}'
                      '${account.isPrimary ? ' · PRIMARY' : ''}'
                      '${account.institution == null || account.institution!.isEmpty ? '' : ' · ${account.institution}'}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (metrics != null) RegisterMetricsBar(metrics: metrics),
                    const RegisterRowLegend(),
                    const SizedBox(height: 8),
                    RegisterFilterBar(
                      filter: _filter,
                      searchFocusNode: _searchFocus,
                      resultCount: visible.length,
                      totalCount: entries.length,
                      onChanged: (next) => setState(() => _filter = next),
                    ),
                    if (loadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        loadError,
                        key: const Key('register_error'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: DecoratedBox(
                        key: ValueKey('register_ledger_$accountId'),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outline),
                          color: AppColors.surface.withValues(alpha: 0.55),
                        ),
                        child: Column(
                          children: [
                            Material(
                              color: AppColors.surfaceElevated
                                  .withValues(alpha: 0.85),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: _RegisterColumnHeader(
                                  textTheme: textTheme,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.outline),
                            Expanded(
                              child: visible.isEmpty
                                  ? Center(
                                      child: Text(
                                        entries.isEmpty
                                            ? 'No transactions yet.'
                                            : 'No rows match this filter.',
                                        key: const Key('register_tx_empty'),
                                        style: textTheme.bodyLarge,
                                      ),
                                    )
                                  : ListView.builder(
                                      key: ValueKey(
                                        'register_tx_list_$accountId',
                                      ),
                                      itemCount: visible.length,
                                      itemBuilder: (context, index) {
                                        final entry = visible[index];
                                        final tx = entry.transaction;
                                        return Column(
                                          key: Key('register_tx_${tx.id}'),
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (index > 0)
                                              const Divider(
                                                height: 1,
                                                color: AppColors.outline,
                                              ),
                                            _RegisterLedgerRow(
                                              entry: entry,
                                              dateLabel: _dateLabel(tx.date),
                                              onClearedChanged:
                                                  tx.isOpeningBalance
                                                      ? null
                                                      : (value) =>
                                                          _toggleCleared(
                                                            tx,
                                                            value,
                                                          ),
                                              onEdit: tx.isOpeningBalance ||
                                                      tx.isCleared
                                                  ? null
                                                  : () =>
                                                      _editTransaction(tx),
                                              onDelete: tx.isOpeningBalance ||
                                                      tx.isCleared
                                                  ? null
                                                  : () =>
                                                      _deleteTransaction(tx),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTransactionIntent extends Intent {
  const _AddTransactionIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ClearFilterIntent extends Intent {
  const _ClearFilterIntent();
}

class _RegisterColumnHeader extends StatelessWidget {
  const _RegisterColumnHeader({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final style = textTheme.labelLarge?.copyWith(
      color: AppColors.onSurfaceMuted,
    );
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text('Clr', textAlign: TextAlign.center, style: style),
        ),
        SizedBox(width: 96, child: Text('Date', style: style)),
        Expanded(child: Text('Payee', style: style)),
        SizedBox(
          width: 88,
          child: Text('Payment', textAlign: TextAlign.end, style: style),
        ),
        SizedBox(
          width: 88,
          child: Text('Deposit', textAlign: TextAlign.end, style: style),
        ),
        SizedBox(
          width: 96,
          child: Text('Balance', textAlign: TextAlign.end, style: style),
        ),
        const SizedBox(width: 88),
      ],
    );
  }
}

class _RegisterLedgerRow extends StatelessWidget {
  const _RegisterLedgerRow({
    required this.entry,
    required this.dateLabel,
    this.onClearedChanged,
    this.onEdit,
    this.onDelete,
  });

  final RegisterEntry entry;
  final String dateLabel;
  final ValueChanged<bool>? onClearedChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tx = entry.transaction;
    final style = RegisterRowStyle.forTransaction(tx);
    final basePayee =
        tx.payee == null || tx.payee!.isEmpty ? '(no payee)' : tx.payee!;
    final payeeLabel = tx.isUserOverridden ? '$basePayee · edited' : basePayee;
    final foreground =
        style.mutedForeground ? AppColors.onSurfaceMuted : AppColors.onSurface;
    final mono = textTheme.bodyMedium?.copyWith(
      fontFamily: AppTheme.monoFont,
      color: foreground,
    );
    final debit = entry.debitCents;
    final credit = entry.creditCents;
    final balance = entry.runningBalanceCents;

    return ColoredBox(
      key: Key('register_tx_style_${tx.id}'),
      color: style.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: style.accent, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      key: Key('register_tx_clear_${tx.id}'),
                      value: tx.isCleared,
                      onChanged: onClearedChanged == null
                          ? null
                          : (value) {
                              if (value != null) {
                                onClearedChanged!(value);
                              }
                            },
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(dateLabel, style: mono),
                  ),
                  Expanded(
                    child: Text(
                      payeeLabel,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: foreground),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      debit == null ? '' : formatCents(debit),
                      textAlign: TextAlign.end,
                      style: mono?.copyWith(
                        color: debit == null
                            ? foreground
                            : (style.mutedForeground
                                ? AppColors.onSurfaceMuted
                                : AppColors.danger),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      credit == null ? '' : formatCents(credit),
                      textAlign: TextAlign.end,
                      style: mono,
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(
                      formatCents(balance),
                      key: Key('register_tx_balance_${tx.id}'),
                      textAlign: TextAlign.end,
                      style: mono?.copyWith(
                        color: balance < 0
                            ? (style.mutedForeground
                                ? AppColors.onSurfaceMuted
                                : AppColors.danger)
                            : foreground,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: onEdit == null && onDelete == null
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  key: Key('register_tx_edit_${tx.id}'),
                                  tooltip: 'Edit',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onEdit,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                              if (onDelete != null)
                                IconButton(
                                  key: Key('register_tx_delete_${tx.id}'),
                                  tooltip: 'Delete',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onDelete,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
              if (tx.memo != null && tx.memo!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 136, top: 2),
                  child: Text(
                    tx.memo!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                )
              else if (tx.isOpeningBalance)
                Padding(
                  padding: const EdgeInsets.only(left: 136, top: 2),
                  child: Text(
                    'Opening balance',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                )
              else if (tx.isCleared)
                Padding(
                  padding: const EdgeInsets.only(left: 136, top: 2),
                  child: Text(
                    'Cleared — unclear to edit',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
