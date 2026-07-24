import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/account.dart';
import '../../data/account_type.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';

/// Modal form to create an account (Phase 1.2).
class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  static Future<AccountDraft?> show(BuildContext context) {
    return showDialog<AccountDraft>(
      context: context,
      builder: (context) => const AddAccountDialog(),
    );
  }

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  final _aprController = TextEditingController();
  final _minPaymentController = TextEditingController();

  AccountType _type = AccountType.checking;
  DateTime _openingDate = DateTime.now();
  bool _includeInDebtList = false;
  int? _dueDay;
  String? _error;

  @override
  void initState() {
    super.initState();
    _includeInDebtList = _type.defaultIncludeInDebtList;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _balanceController.dispose();
    _aprController.dispose();
    _minPaymentController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    try {
      final draft = AccountDraft(
        name: _nameController.text,
        type: _type,
        institution: _institutionController.text,
        interestRateApr: _parseOptionalApr(_aprController.text),
        minimumPaymentCents: _parseOptionalCents(_minPaymentController.text),
        paymentDueDay: _dueDay,
        includeInDebtList: _includeInDebtList,
        openingBalanceCents: parseDollarsToCents(_balanceController.text),
        openingDate: _openingDate,
      );
      Navigator.of(context).pop(draft);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message);
    }
  }

  double? _parseOptionalApr(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      throw const FormatException('Enter a valid APR (e.g. 19.99)');
    }
    return value;
  }

  int? _parseOptionalCents(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    return parseDollarsToCents(text);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _openingDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateLabel =
        '${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')}';

    return AlertDialog(
      key: const Key('add_account_dialog'),
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('Add account'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('add_account_name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                key: const Key('add_account_type'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final type in AccountType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _type = value;
                    _includeInDebtList = value.defaultIncludeInDebtList;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add_account_institution'),
                controller: _institutionController,
                decoration: const InputDecoration(
                  labelText: 'Institution (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add_account_balance'),
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\$\.,\-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Opening balance',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opening date'),
                subtitle: Text(dateLabel),
                trailing: OutlinedButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
              ),
              TextField(
                key: const Key('add_account_apr'),
                controller: _aprController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'APR % (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add_account_min_payment'),
                controller: _minPaymentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Minimum payment (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: const Key('add_account_due_day'),
                initialValue: _dueDay,
                decoration: const InputDecoration(
                  labelText: 'Payment due day (optional)',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None'),
                  ),
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('$day')),
                ],
                onChanged: (value) => setState(() => _dueDay = value),
              ),
              CheckboxListTile(
                key: const Key('add_account_debt_list'),
                contentPadding: EdgeInsets.zero,
                value: _includeInDebtList,
                onChanged: (value) =>
                    setState(() => _includeInDebtList = value ?? false),
                title: Text(
                  'Include in Debts list',
                  style: textTheme.bodyMedium,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
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
          key: const Key('add_account_submit'),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
