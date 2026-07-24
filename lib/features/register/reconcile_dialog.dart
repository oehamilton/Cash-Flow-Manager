import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/money.dart';
import '../../data/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Statement ending-balance reconcile helper (Phase 2.3).
///
/// Clear transactions in the register, then finish when the difference is zero.
class ReconcileDialog extends StatefulWidget {
  const ReconcileDialog({
    super.key,
    required this.accountId,
    required this.repository,
    required this.clearedBalanceCents,
  });

  final String accountId;
  final TransactionRepository repository;
  final int clearedBalanceCents;

  static Future<bool?> show(
    BuildContext context, {
    required String accountId,
    required TransactionRepository repository,
    required int clearedBalanceCents,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ReconcileDialog(
        accountId: accountId,
        repository: repository,
        clearedBalanceCents: clearedBalanceCents,
      ),
    );
  }

  @override
  State<ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends State<ReconcileDialog> {
  late final TextEditingController _statementController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statementController = TextEditingController(
      text: formatCents(widget.clearedBalanceCents).replaceFirst(r'$', ''),
    );
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  int? get _statementCents {
    final raw = _statementController.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      return parseDollarsToCents(raw);
    } on FormatException {
      return null;
    }
  }

  int? get _difference {
    final statement = _statementCents;
    if (statement == null) {
      return null;
    }
    return statement - widget.clearedBalanceCents;
  }

  void _finish() {
    setState(() => _error = null);
    final statement = _statementCents;
    if (statement == null) {
      setState(() => _error = 'Enter a valid statement ending balance');
      return;
    }
    try {
      widget.repository.finishReconcile(
        accountId: widget.accountId,
        statementEndingBalanceCents: statement,
      );
      Navigator.of(context).pop(true);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final difference = _difference;
    final balanced = difference == 0;

    return AlertDialog(
      key: const Key('reconcile_dialog'),
      backgroundColor: AppColors.surface,
      title: const Text('Reconcile'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Clear matching transactions in the register, then enter the '
              'ending balance from your statement.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('reconcile_statement_field'),
              controller: _statementController,
              decoration: const InputDecoration(
                labelText: 'Statement ending balance',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-$,]')),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _metricRow(
              'Cleared balance',
              formatCents(widget.clearedBalanceCents),
              keyName: 'reconcile_cleared_balance',
            ),
            const SizedBox(height: 8),
            _metricRow(
              'Difference',
              difference == null ? '—' : formatCents(difference),
              keyName: 'reconcile_difference',
              emphasize: difference != null && difference != 0,
            ),
            if (balanced) ...[
              const SizedBox(height: 12),
              Text(
                'Balances match. You can finish reconcile.',
                key: const Key('reconcile_balanced_hint'),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryBright,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        FilledButton(
          key: const Key('reconcile_finish_button'),
          onPressed: balanced ? _finish : null,
          child: const Text('Finish'),
        ),
      ],
    );
  }

  Widget _metricRow(
    String label,
    String value, {
    required String keyName,
    bool emphasize = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Text(
          value,
          key: Key(keyName),
          style: textTheme.titleMedium?.copyWith(
            fontFamily: AppTheme.monoFont,
            color: emphasize ? AppColors.danger : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
