import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/account_repository.dart';
import '../../data/money.dart';
import '../../data/recurrence_rule.dart';
import '../../data/recurrence_rule_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'recurrence_editor_dialog.dart';

/// Manage recurrence rules for one account (Phase 3.1).
class RecurrencePage extends StatefulWidget {
  const RecurrencePage({
    super.key,
    required this.auth,
    required this.accountId,
    required this.onClose,
  });

  final AuthService auth;
  final String accountId;
  final VoidCallback onClose;

  @override
  State<RecurrencePage> createState() => _RecurrencePageState();
}

class _RecurrencePageState extends State<RecurrencePage> {
  List<RecurrenceRule> _rules = const [];
  String? _accountName;
  String? _error;

  RecurrenceRuleRepository? get _repo {
    final session = widget.auth.session;
    if (session == null) {
      return null;
    }
    return RecurrenceRuleRepository(session);
  }

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  void _reload({bool initial = false}) {
    final session = widget.auth.session;
    List<RecurrenceRule> rules = const [];
    String? name;
    String? error;
    if (session == null) {
      error = 'Vault is locked';
    } else {
      try {
        final account = AccountRepository(session).getById(widget.accountId);
        name = account?.name;
        rules = RecurrenceRuleRepository(session).listForAccount(
          widget.accountId,
        );
      } on Object catch (e) {
        error = e.toString();
      }
    }
    if (initial) {
      _rules = rules;
      _accountName = name;
      _error = error;
      return;
    }
    setState(() {
      _rules = rules;
      _accountName = name;
      _error = error;
    });
  }

  Future<void> _add() async {
    final repo = _repo;
    if (repo == null) {
      return;
    }
    final result = await RecurrenceEditorDialog.show(context);
    if (result == null || !mounted) {
      return;
    }
    try {
      repo.create(
        RecurrenceRuleDraft(
          accountId: widget.accountId,
          payee: result.payee,
          memo: result.memo,
          amountCents: result.amountCents,
          frequency: result.frequency,
          interval: result.interval,
          anchorDate: result.anchorDate,
          endDate: result.endDate,
          autoClear: result.autoClear,
          isActive: result.isActive,
        ),
      );
      _reload();
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _edit(RecurrenceRule rule) async {
    final repo = _repo;
    if (repo == null) {
      return;
    }
    final result = await RecurrenceEditorDialog.show(context, initial: rule);
    if (result == null || !mounted) {
      return;
    }
    try {
      repo.update(
        rule.id,
        RecurrenceRuleUpdate(
          payee: result.payee,
          memo: result.memo,
          clearMemo: result.memo == null || result.memo!.trim().isEmpty,
          amountCents: result.amountCents,
          frequency: result.frequency,
          interval: result.interval,
          anchorDate: result.anchorDate,
          endDate: result.endDate,
          clearEndDate: result.endDate == null,
          autoClear: result.autoClear,
          isActive: result.isActive,
        ),
      );
      _reload();
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _delete(RecurrenceRule rule) async {
    final repo = _repo;
    if (repo == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete recurring item?'),
        content: Text('Delete "${rule.payee}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('recurrence_confirm_delete'),
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
      repo.delete(rule.id);
      _reload();
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
    return DecoratedBox(
      key: const Key('page_recurrence'),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('recurrence_back'),
                  tooltip: 'Back to register',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    _accountName == null
                        ? 'Recurring'
                        : 'Recurring — $_accountName',
                    key: const Key('recurrence_title'),
                    style: textTheme.headlineMedium,
                  ),
                ),
                FilledButton.icon(
                  key: const Key('recurrence_add'),
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rules for this account. Instances appear on the register in Phase 3.2.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outline),
                  color: AppColors.surface.withValues(alpha: 0.55),
                ),
                child: _rules.isEmpty
                    ? Center(
                        child: Text(
                          'No recurring items yet.',
                          key: const Key('recurrence_empty'),
                          style: textTheme.bodyLarge,
                        ),
                      )
                    : ListView.separated(
                        key: const Key('recurrence_list'),
                        itemCount: _rules.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.outline,
                        ),
                        itemBuilder: (context, index) {
                          final rule = _rules[index];
                          final amountLabel = rule.amountCents < 0
                              ? 'Payment ${formatCents(-rule.amountCents)}'
                              : 'Deposit ${formatCents(rule.amountCents)}';
                          return ListTile(
                            key: Key('recurrence_row_${rule.id}'),
                            title: Text(rule.payee),
                            subtitle: Text(
                              '${rule.frequency.label}'
                              '${rule.interval == 1 ? '' : ' ×${rule.interval}'}'
                              ' · from ${_dateLabel(rule.anchorDate)}'
                              '${rule.isActive ? '' : ' · inactive'}',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceMuted,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  amountLabel,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontFamily: AppTheme.monoFont,
                                    color: rule.amountCents < 0
                                        ? AppColors.danger
                                        : AppColors.onSurface,
                                  ),
                                ),
                                IconButton(
                                  key: Key('recurrence_edit_${rule.id}'),
                                  tooltip: 'Edit',
                                  onPressed: () => _edit(rule),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  key: Key('recurrence_delete_${rule.id}'),
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(rule),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
