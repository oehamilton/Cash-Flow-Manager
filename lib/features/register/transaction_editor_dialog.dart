import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/money.dart';
import '../../data/transaction.dart';
import '../../theme/app_colors.dart';

/// Result of the add/edit transaction dialog.
class TransactionEditorResult {
  const TransactionEditorResult({
    required this.date,
    this.payee,
    this.memo,
    required this.amountCents,
  });

  final DateTime date;
  final String? payee;
  final String? memo;
  final int amountCents;
}

/// Modal form to create or edit a register transaction (Phase 2.1).
class TransactionEditorDialog extends StatefulWidget {
  const TransactionEditorDialog({
    super.key,
    required this.suggestions,
    this.initial,
  });

  final List<String> suggestions;
  final Transaction? initial;

  static Future<TransactionEditorResult?> show(
    BuildContext context, {
    required List<String> suggestions,
    Transaction? initial,
  }) {
    return showDialog<TransactionEditorResult>(
      context: context,
      builder: (context) => TransactionEditorDialog(
        suggestions: suggestions,
        initial: initial,
      ),
    );
  }

  @override
  State<TransactionEditorDialog> createState() =>
      _TransactionEditorDialogState();
}

class _TransactionEditorDialogState extends State<TransactionEditorDialog> {
  late final TextEditingController _memoController;
  late final TextEditingController _amountController;
  late DateTime _date;
  String _payeeText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _payeeText = initial?.payee ?? '';
    _memoController = TextEditingController(text: initial?.memo ?? '');
    _amountController = TextEditingController(
      text: initial == null
          ? ''
          : formatCents(initial.amountCents).replaceFirst(r'$', ''),
    );
    _date = initial?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _memoController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    try {
      final result = TransactionEditorResult(
        date: _date,
        payee: _payeeText,
        memo: _memoController.text,
        amountCents: parseDollarsToCents(_amountController.text),
      );
      Navigator.of(context).pop(result);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _date = picked);
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
    final isEdit = widget.initial != null;
    return AlertDialog(
      key: const Key('transaction_editor_dialog'),
      backgroundColor: AppColors.surface,
      title: Text(isEdit ? 'Edit transaction' : 'Add transaction'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('tx_date_button'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(_dateLabel(_date)),
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) {
                  return widget.suggestions.take(12);
                }
                return widget.suggestions
                    .where((s) => s.toLowerCase().contains(q))
                    .take(12);
              },
              initialValue: TextEditingValue(text: _payeeText),
              onSelected: (value) {
                setState(() => _payeeText = value);
              },
              fieldViewBuilder: (
                context,
                textEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  key: const Key('tx_payee_field'),
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Payee',
                    hintText: 'Start typing for suggestions',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (value) => _payeeText = value,
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tx_memo_field'),
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'Memo'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tx_amount_field'),
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '+ deposit / − payment',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-$,]')),
              ],
              onSubmitted: (_) => _submit(),
            ),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('tx_save_button'),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
