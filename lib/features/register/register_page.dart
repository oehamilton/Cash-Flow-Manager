import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/money.dart';
import '../../data/transaction.dart';
import '../../data/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'transaction_editor_dialog.dart';

/// Register surface: account header + ledger with credit/debit/balance.
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
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _editTransaction(Transaction tx) async {
    if (tx.isOpeningBalance) {
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
    if (tx.isOpeningBalance) {
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

    Account? account;
    var balanceCents = 0;
    List<RegisterEntry> entries = const [];
    String? loadError = _error;

    if (session != null && accountId != null) {
      try {
        final accounts = AccountRepository(session);
        account = accounts.getById(accountId);
        if (account != null) {
          // Always scope by the widget account id (not cached state).
          balanceCents = accounts.balanceCents(accountId);
          entries =
              TransactionRepository(session).listRegisterEntries(accountId);
        }
      } on Object catch (e) {
        loadError = e.toString();
      }
    }

    return DecoratedBox(
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
        padding: const EdgeInsets.all(32),
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
                if (account != null)
                  FilledButton.icon(
                    key: const Key('register_add_tx'),
                    onPressed: () => _addTransaction(account!),
                    icon: const Icon(Icons.add),
                    label: const Text('Add transaction'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Balance',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontFamily: AppTheme.monoFont,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCents(balanceCents),
                key: const Key('register_balance'),
                style: textTheme.headlineSmall?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: balanceCents < 0
                      ? AppColors.danger
                      : AppColors.onSurface,
                ),
              ),
              if (loadError != null) ...[
                const SizedBox(height: 12),
                Text(
                  loadError,
                  key: const Key('register_error'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: DecoratedBox(
                  key: ValueKey('register_ledger_$accountId'),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.outline),
                    color: AppColors.surface.withValues(alpha: 0.55),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: _RegisterColumnHeader(textTheme: textTheme),
                      ),
                      const Divider(height: 1, color: AppColors.outline),
                      Expanded(
                        child: entries.isEmpty
                            ? Center(
                                child: Text(
                                  'No transactions yet.',
                                  key: const Key('register_tx_empty'),
                                  style: textTheme.bodyLarge,
                                ),
                              )
                            : ListView.builder(
                                key: ValueKey('register_tx_list_$accountId'),
                                itemCount: entries.length,
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
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
                                        onEdit: tx.isOpeningBalance
                                            ? null
                                            : () => _editTransaction(tx),
                                        onDelete: tx.isOpeningBalance
                                            ? null
                                            : () => _deleteTransaction(tx),
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
    );
  }
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
        SizedBox(width: 96, child: Text('Date', style: style)),
        Expanded(child: Text('Payee', style: style)),
        SizedBox(
          width: 96,
          child: Text('Payment', textAlign: TextAlign.end, style: style),
        ),
        SizedBox(
          width: 96,
          child: Text('Deposit', textAlign: TextAlign.end, style: style),
        ),
        SizedBox(
          width: 104,
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
    this.onEdit,
    this.onDelete,
  });

  final RegisterEntry entry;
  final String dateLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tx = entry.transaction;
    final payeeLabel =
        tx.payee == null || tx.payee!.isEmpty ? '(no payee)' : tx.payee!;
    final mono = textTheme.bodyMedium?.copyWith(fontFamily: AppTheme.monoFont);
    final debit = entry.debitCents;
    final credit = entry.creditCents;
    final balance = entry.runningBalanceCents;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(dateLabel, style: mono),
              ),
              Expanded(
                child: Text(payeeLabel, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  debit == null ? '' : formatCents(debit),
                  textAlign: TextAlign.end,
                  style: mono?.copyWith(color: AppColors.danger),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  credit == null ? '' : formatCents(credit),
                  textAlign: TextAlign.end,
                  style: mono,
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  formatCents(balance),
                  key: Key('register_tx_balance_${tx.id}'),
                  textAlign: TextAlign.end,
                  style: mono?.copyWith(
                    color: balance < 0 ? AppColors.danger : AppColors.onSurface,
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                child: onEdit == null
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            key: Key('register_tx_edit_${tx.id}'),
                            tooltip: 'Edit',
                            visualDensity: VisualDensity.compact,
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            key: Key('register_tx_delete_${tx.id}'),
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (tx.memo != null && tx.memo!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 96, top: 2),
              child: Text(
                tx.memo!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            )
          else if (tx.isOpeningBalance)
            Padding(
              padding: const EdgeInsets.only(left: 96, top: 2),
              child: Text(
                'Opening balance',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
