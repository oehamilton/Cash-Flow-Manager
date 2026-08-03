import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/money.dart';
import '../../data/payee_suggestion.dart';
import '../../data/transaction.dart';
import '../../theme/app_colors.dart';

/// Result of the add/edit transaction dialog.
class TransactionEditorResult {
  const TransactionEditorResult({
    required this.date,
    this.payee,
    this.payeeId,
    this.transferToAccountId,
    this.clearTransfer = false,
    this.memo,
    required this.amountCents,
    this.interestCents,
    this.principalCents,
    this.clearInterest = false,
    this.clearPrincipal = false,
  });

  final DateTime date;
  final String? payee;
  final String? payeeId;
  final String? transferToAccountId;
  final bool clearTransfer;
  final String? memo;
  final int amountCents;
  final int? interestCents;
  final int? principalCents;
  final bool clearInterest;
  final bool clearPrincipal;
}

/// Modal form to create or edit a register transaction.
///
/// Amounts use separate Payment (debit) and Deposit (credit) fields.
/// Selecting an account payee (→ Name) creates a linked transfer (Phase 6.1).
class TransactionEditorDialog extends StatefulWidget {
  const TransactionEditorDialog({
    super.key,
    required this.suggestions,
    this.initial,
    this.initialTransferAccountId,
    this.showInterestPrincipal = false,
  });

  final List<PayeeSuggestion> suggestions;
  final Transaction? initial;
  final String? initialTransferAccountId;
  final bool showInterestPrincipal;

  static Future<TransactionEditorResult?> show(
    BuildContext context, {
    required List<PayeeSuggestion> suggestions,
    Transaction? initial,
    String? initialTransferAccountId,
    bool showInterestPrincipal = false,
  }) {
    return showDialog<TransactionEditorResult>(
      context: context,
      builder: (context) => TransactionEditorDialog(
        suggestions: suggestions,
        initial: initial,
        initialTransferAccountId: initialTransferAccountId,
        showInterestPrincipal: showInterestPrincipal,
      ),
    );
  }

  @override
  State<TransactionEditorDialog> createState() =>
      _TransactionEditorDialogState();
}

class _TransactionEditorDialogState extends State<TransactionEditorDialog> {
  late final TextEditingController _memoController;
  late final TextEditingController _paymentController;
  late final TextEditingController _depositController;
  late final TextEditingController _interestController;
  late final TextEditingController _principalController;
  late DateTime _date;
  String _payeeText = '';
  String? _transferAccountId;
  String? _managedPayeeId;
  String? _error;

  static final _amountAllow = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.$,]'),
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _payeeText = initial?.payee ?? '';
    _transferAccountId = widget.initialTransferAccountId;
    _managedPayeeId = initial?.payeeId;
    if (_transferAccountId != null) {
      final match = widget.suggestions.whereType<AccountPayeeSuggestion>().where(
            (s) => s.accountId == _transferAccountId,
          );
      if (match.isNotEmpty) {
        _payeeText = match.first.label;
      }
    }
    _memoController = TextEditingController(text: initial?.memo ?? '');
    final amount = initial?.amountCents ?? 0;
    _paymentController = TextEditingController(
      text: amount < 0 ? _plainCents(-amount) : '',
    );
    _depositController = TextEditingController(
      text: amount > 0 ? _plainCents(amount) : '',
    );
    _interestController = TextEditingController(
      text: initial?.interestCents == null
          ? ''
          : _plainCents(initial!.interestCents!),
    );
    _principalController = TextEditingController(
      text: initial?.principalCents == null
          ? ''
          : _plainCents(initial!.principalCents!),
    );
    _date = initial?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _memoController.dispose();
    _paymentController.dispose();
    _depositController.dispose();
    _interestController.dispose();
    _principalController.dispose();
    super.dispose();
  }

  static String _plainCents(int cents) =>
      formatCents(cents).replaceFirst(r'$', '');

  int? _optionalCents(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return parseDollarsToCents(trimmed);
  }

  void _onPayeeTextChanged(String value) {
    _payeeText = value;
    // Typing freely clears structured selection unless it still matches.
    final stillAccount = widget.suggestions
        .whereType<AccountPayeeSuggestion>()
        .any((s) => s.label == value || s.account.name == value);
    if (!stillAccount) {
      _transferAccountId = null;
    }
    final stillManaged = widget.suggestions
        .whereType<ManagedPayeeSuggestion>()
        .any((s) => s.label == value);
    if (!stillManaged) {
      _managedPayeeId = null;
    }
  }

  void _onPayeeSelected(PayeeSuggestion suggestion) {
    setState(() {
      _payeeText = suggestion.label;
      switch (suggestion) {
        case AccountPayeeSuggestion(:final accountId):
          _transferAccountId = accountId;
          _managedPayeeId = null;
        case ManagedPayeeSuggestion(:final payeeId):
          _managedPayeeId = payeeId;
          _transferAccountId = null;
          _payeeText = suggestion.label;
        case TextPayeeSuggestion(:final name):
          _payeeText = name;
          _transferAccountId = null;
          _managedPayeeId = null;
      }
    });
  }

  void _submit() {
    setState(() => _error = null);
    try {
      final paymentRaw = _paymentController.text.trim();
      final depositRaw = _depositController.text.trim();
      final hasPayment = paymentRaw.isNotEmpty;
      final hasDeposit = depositRaw.isNotEmpty;
      if (hasPayment == hasDeposit) {
        throw const FormatException(
          'Enter either a Payment or a Deposit (not both)',
        );
      }
      final amountCents = hasPayment
          ? -parseDollarsToCents(paymentRaw)
          : parseDollarsToCents(depositRaw);
      if (amountCents == 0) {
        throw const FormatException('Amount cannot be zero');
      }

      int? interestCents;
      int? principalCents;
      var clearInterest = false;
      var clearPrincipal = false;
      if (widget.showInterestPrincipal && _transferAccountId == null) {
        interestCents = _optionalCents(_interestController.text);
        principalCents = _optionalCents(_principalController.text);
        clearInterest = interestCents == null;
        clearPrincipal = principalCents == null;
        validateInterestPrincipalSplit(
          amountCents: amountCents,
          interestCents: interestCents,
          principalCents: principalCents,
        );
      }

      final wasTransfer = widget.initialTransferAccountId != null;
      final clearTransfer =
          wasTransfer && _transferAccountId == null;

      // Prefer account display name over "→ Name" for stored free-text fallback.
      var payeeOut = _payeeText.trim();
      if (_transferAccountId != null) {
        final match = widget.suggestions
            .whereType<AccountPayeeSuggestion>()
            .where((s) => s.accountId == _transferAccountId);
        if (match.isNotEmpty) {
          payeeOut = match.first.account.name;
        }
      } else if (payeeOut.startsWith('→ ')) {
        payeeOut = payeeOut.substring(2).trim();
      }

      Navigator.of(context).pop(
        TransactionEditorResult(
          date: _date,
          payee: payeeOut.isEmpty ? null : payeeOut,
          payeeId: _managedPayeeId,
          transferToAccountId: _transferAccountId,
          clearTransfer: clearTransfer,
          memo: _memoController.text,
          amountCents: amountCents,
          interestCents: interestCents,
          principalCents: principalCents,
          clearInterest: clearInterest,
          clearPrincipal: clearPrincipal,
        ),
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError catch (e) {
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

  bool get _isFutureDate {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final d = DateTime(_date.year, _date.month, _date.day);
    return d.isAfter(todayDate);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final isTransfer = _transferAccountId != null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
      },
      child: AlertDialog(
        key: const Key('transaction_editor_dialog'),
        backgroundColor: AppColors.surface,
        title: Text(isEdit ? 'Edit transaction' : 'Add transaction'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
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
                if (widget.initial?.isRecurringGenerated == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      key: const Key('tx_generated_hint'),
                      'Recurring instance — your edits are kept (until cleared).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryBright,
                          ),
                    ),
                  )
                else if (_isFutureDate)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      key: const Key('tx_future_hint'),
                      'Future date — saved as a manual forecast row.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                          ),
                    ),
                  ),
                if (isTransfer)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      key: const Key('tx_transfer_hint'),
                      'Transfer — a matching entry will be created on the other account.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryBright,
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
                Autocomplete<PayeeSuggestion>(
                  optionsBuilder: (textEditingValue) {
                    final q = textEditingValue.text.trim().toLowerCase();
                    if (q.isEmpty) {
                      return widget.suggestions.take(12);
                    }
                    return widget.suggestions
                        .where(
                          (s) =>
                              s.label.toLowerCase().contains(q) ||
                              (s is AccountPayeeSuggestion &&
                                  s.account.name.toLowerCase().contains(q)),
                        )
                        .take(12);
                  },
                  displayStringForOption: (s) => s.label,
                  initialValue: TextEditingValue(text: _payeeText),
                  onSelected: _onPayeeSelected,
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
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Payee',
                        hintText: 'Account, payee, or type freely',
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onPayeeTextChanged,
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        color: AppColors.surface,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final icon = switch (option) {
                                AccountPayeeSuggestion() =>
                                  Icons.swap_horiz,
                                ManagedPayeeSuggestion() =>
                                  Icons.person_outline,
                                TextPayeeSuggestion() => Icons.history,
                              };
                              return ListTile(
                                dense: true,
                                leading: Icon(icon, size: 18),
                                title: Text(option.label),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('tx_payment_field'),
                        controller: _paymentController,
                        decoration: const InputDecoration(
                          labelText: 'Payment',
                          hintText: 'Debit · Enter to save',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_amountAllow],
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_paymentController.text.trim().isNotEmpty) {
                            _depositController.clear();
                          }
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('tx_deposit_field'),
                        controller: _depositController,
                        decoration: const InputDecoration(
                          labelText: 'Deposit',
                          hintText: 'Credit · Enter to save',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_amountAllow],
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_depositController.text.trim().isNotEmpty) {
                            _paymentController.clear();
                          }
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ],
                ),
                if (widget.showInterestPrincipal && !isTransfer) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Optional split (for charts)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('tx_interest_field'),
                          controller: _interestController,
                          decoration: const InputDecoration(
                            labelText: 'Interest',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_amountAllow],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('tx_principal_field'),
                          controller: _principalController,
                          decoration: const InputDecoration(
                            labelText: 'Principal',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_amountAllow],
                        ),
                      ),
                    ],
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
      ),
    );
  }
}
