import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/money.dart';
import '../../data/recurrence_frequency.dart';
import '../../data/recurrence_materializer.dart';
import '../../data/recurrence_rule.dart';
import '../../data/recurrence_schedule.dart';
import '../../theme/app_colors.dart';

class RecurrenceEditorResult {
  const RecurrenceEditorResult({
    required this.payee,
    this.memo,
    required this.amountCents,
    required this.frequency,
    required this.interval,
    required this.anchorDate,
    this.endDate,
    required this.autoClear,
    required this.isActive,
  });

  final String payee;
  final String? memo;
  final int amountCents;
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime anchorDate;
  final DateTime? endDate;
  final bool autoClear;
  final bool isActive;
}

class RecurrenceEditorDialog extends StatefulWidget {
  const RecurrenceEditorDialog({super.key, this.initial});

  final RecurrenceRule? initial;

  static Future<RecurrenceEditorResult?> show(
    BuildContext context, {
    RecurrenceRule? initial,
  }) {
    return showDialog<RecurrenceEditorResult>(
      context: context,
      builder: (context) => RecurrenceEditorDialog(initial: initial),
    );
  }

  @override
  State<RecurrenceEditorDialog> createState() => _RecurrenceEditorDialogState();
}

class _RecurrenceEditorDialogState extends State<RecurrenceEditorDialog> {
  late final TextEditingController _payeeController;
  late final TextEditingController _memoController;
  late final TextEditingController _paymentController;
  late final TextEditingController _depositController;
  late final TextEditingController _intervalController;
  late RecurrenceFrequency _frequency;
  late DateTime _anchorDate;
  DateTime? _endDate;
  late bool _autoClear;
  late bool _isActive;
  String? _error;

  static final _amountAllow = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.$,]'),
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _payeeController = TextEditingController(text: initial?.payee ?? '');
    _memoController = TextEditingController(text: initial?.memo ?? '');
    final amount = initial?.amountCents ?? 0;
    _paymentController = TextEditingController(
      text: amount < 0 ? _plain(amount.abs()) : '',
    );
    _depositController = TextEditingController(
      text: amount > 0 ? _plain(amount) : '',
    );
    _intervalController = TextEditingController(
      text: '${initial?.interval ?? 1}',
    );
    _intervalController.addListener(() => setState(() {}));
    _frequency = initial?.frequency ?? RecurrenceFrequency.monthly;
    _anchorDate = initial?.anchorDate ?? DateTime.now();
    _endDate = initial?.endDate;
    _autoClear = initial?.autoClear ?? false;
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _memoController.dispose();
    _paymentController.dispose();
    _depositController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  static String _plain(int cents) => formatCents(cents).replaceFirst(r'$', '');

  String _dateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get _intervalHelper => switch (_frequency) {
        RecurrenceFrequency.daily => '1 = every day, 2 = every other day',
        RecurrenceFrequency.weekly =>
          '1 = every week; use 2 for every two weeks',
        RecurrenceFrequency.biweekly =>
          'Leave at 1 for every two weeks (2 = every 4 weeks)',
        RecurrenceFrequency.semimonthly => 'Leave at 1 (twice each month)',
        RecurrenceFrequency.monthly =>
          '1 = every month (this is not weeks)',
        RecurrenceFrequency.quarterly => '1 = every quarter',
        RecurrenceFrequency.yearly => '1 = every year',
      };

  /// Dates the materializer will insert for the ~2-month horizon.
  List<DateTime> get _previewDates {
    final interval = int.tryParse(_intervalController.text.trim()) ?? 0;
    if (interval < 1) {
      return const [];
    }
    final today = RecurrenceSchedule.dateOnly(DateTime.now());
    return RecurrenceSchedule.occurrencesInRange(
      anchor: _anchorDate,
      start: today,
      end: today.add(
        const Duration(days: RecurrenceMaterializer.defaultHorizonDays),
      ),
      frequency: _frequency,
      interval: interval,
      ruleEnd: _endDate,
    );
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
      final interval = int.tryParse(_intervalController.text.trim());
      if (interval == null || interval < 1) {
        throw const FormatException('Interval must be a whole number ≥ 1');
      }
      final payee = _payeeController.text.trim();
      if (payee.isEmpty) {
        throw const FormatException('Payee is required');
      }
      Navigator.of(context).pop(
        RecurrenceEditorResult(
          payee: payee,
          memo: _memoController.text,
          amountCents: amountCents,
          frequency: _frequency,
          interval: interval,
          anchorDate: _anchorDate,
          endDate: _endDate,
          autoClear: _autoClear,
          isActive: _isActive,
        ),
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _anchorDate = picked);
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _anchorDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      key: const Key('recurrence_editor_dialog'),
      backgroundColor: AppColors.surface,
      title: Text(isEdit ? 'Edit recurring' : 'Add recurring'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('recurrence_payee_field'),
                controller: _payeeController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Payee'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recurrence_memo_field'),
                controller: _memoController,
                decoration: const InputDecoration(labelText: 'Memo'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('recurrence_payment_field'),
                      controller: _paymentController,
                      decoration: const InputDecoration(labelText: 'Payment'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_amountAllow],
                      onChanged: (_) {
                        if (_paymentController.text.trim().isNotEmpty) {
                          _depositController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('recurrence_deposit_field'),
                      controller: _depositController,
                      decoration: const InputDecoration(labelText: 'Deposit'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_amountAllow],
                      onChanged: (_) {
                        if (_depositController.text.trim().isNotEmpty) {
                          _paymentController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                key: const Key('recurrence_frequency_field'),
                // ignore: deprecated_member_use
                value: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: [
                  for (final f in RecurrenceFrequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _frequency = value;
                    if (value == RecurrenceFrequency.biweekly ||
                        value == RecurrenceFrequency.semimonthly) {
                      _intervalController.text = '1';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recurrence_interval_field'),
                controller: _intervalController,
                decoration: InputDecoration(
                  labelText: 'Interval',
                  helperText: _intervalHelper,
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    key: const Key('recurrence_anchor_button'),
                    onPressed: _pickAnchor,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('Starts ${_dateLabel(_anchorDate)}'),
                  ),
                  TextButton.icon(
                    key: const Key('recurrence_end_button'),
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: Text(
                      _endDate == null
                          ? 'No end date'
                          : 'Ends ${_dateLabel(_endDate!)}',
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(
                      key: const Key('recurrence_end_clear'),
                      tooltip: 'Clear end date',
                      onPressed: () => setState(() => _endDate = null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final preview = _previewDates;
                  final style = Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      );
                  if (preview.isEmpty) {
                    return Text(
                      key: const Key('recurrence_preview_empty'),
                      'No register rows in the next '
                      '~${RecurrenceMaterializer.defaultHorizonDays} days '
                      'with these settings.',
                      style: style,
                    );
                  }
                  final labels = preview.map(_dateLabel).join(', ');
                  return Text(
                    key: const Key('recurrence_preview'),
                    'Will add ${preview.length} register '
                    'row${preview.length == 1 ? '' : 's'}: $labels',
                    style: style,
                  );
                },
              ),
              SwitchListTile(
                key: const Key('recurrence_active_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              SwitchListTile(
                key: const Key('recurrence_autoclear_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-clear when posted'),
                subtitle: const Text('Used when instances are generated'),
                value: _autoClear,
                onChanged: (value) => setState(() => _autoClear = value),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
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
          key: const Key('recurrence_save_button'),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
