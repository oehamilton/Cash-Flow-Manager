import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/account_type.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Editable account metadata and credentials (Phase 1.3).
class AccountInfoPage extends StatefulWidget {
  const AccountInfoPage({
    super.key,
    required this.auth,
    required this.accountId,
    required this.onClose,
    this.onChanged,
    this.onOpenRegister,
  });

  final AuthService auth;
  final String accountId;
  final VoidCallback onClose;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onOpenRegister;

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _loginUrlController = TextEditingController();
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _notesController = TextEditingController();
  final _aprController = TextEditingController();
  final _minPaymentController = TextEditingController();

  Account? _account;
  AccountType _type = AccountType.checking;
  bool _includeInDebtList = false;
  int? _dueDay;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _accountNumberController.dispose();
    _loginUrlController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _notesController.dispose();
    _aprController.dispose();
    _minPaymentController.dispose();
    super.dispose();
  }

  AccountRepository? get _repoOrNull {
    final session = widget.auth.session;
    if (session == null) {
      return null;
    }
    return AccountRepository(session);
  }

  void _load({bool initial = false}) {
    final repo = _repoOrNull;
    if (repo == null) {
      _account = null;
      _error = 'Vault is locked';
      return;
    }
    final account = repo.getById(widget.accountId);
    if (account == null) {
      _account = null;
      if (initial) {
        _error = 'Account not found';
      } else {
        setState(() => _error = 'Account not found');
      }
      return;
    }
    _account = account;
    _nameController.text = account.name;
    _institutionController.text = account.institution ?? '';
    _accountNumberController.text = account.accountNumber ?? '';
    _loginUrlController.text = account.loginUrl ?? '';
    _loginUsernameController.text = account.loginUsername ?? '';
    _loginPasswordController.text = account.loginPassword ?? '';
    _contactNameController.text = account.contactName ?? '';
    _contactPhoneController.text = account.contactPhone ?? '';
    _contactEmailController.text = account.contactEmail ?? '';
    _notesController.text = account.notes ?? '';
    _aprController.text = account.interestRateApr?.toString() ?? '';
    _minPaymentController.text = account.minimumPaymentCents == null
        ? ''
        : _centsToEditable(account.minimumPaymentCents!);
    _type = account.type;
    _includeInDebtList = account.includeInDebtList;
    _dueDay = account.paymentDueDay;
    _error = null;
    if (!initial) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    final repo = _repoOrNull;
    if (repo == null) {
      setState(() => _error = 'Vault is locked');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final aprText = _aprController.text.trim();
      final minText = _minPaymentController.text.trim();
      repo.update(
        widget.accountId,
        AccountUpdate(
          name: _nameController.text,
          type: _type,
          institution: _institutionController.text,
          accountNumber: _accountNumberController.text,
          loginUrl: _loginUrlController.text,
          loginUsername: _loginUsernameController.text,
          loginPassword: _loginPasswordController.text,
          clearLoginPassword: _loginPasswordController.text.trim().isEmpty,
          contactName: _contactNameController.text,
          contactPhone: _contactPhoneController.text,
          contactEmail: _contactEmailController.text,
          notes: _notesController.text,
          interestRateApr: aprText.isEmpty ? null : double.parse(aprText),
          clearInterestRateApr: aprText.isEmpty,
          minimumPaymentCents:
              minText.isEmpty ? null : parseDollarsToCents(minText),
          clearMinimumPaymentCents: minText.isEmpty,
          paymentDueDay: _dueDay,
          clearPaymentDueDay: _dueDay == null,
          includeInDebtList: _includeInDebtList,
        ),
      );
      _load();
      widget.onChanged?.call();
      setState(() => _status = 'Saved');
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    } on Object catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setPrimary() async {
    final repo = _repoOrNull;
    if (repo == null) {
      setState(() => _error = 'Vault is locked');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      repo.setPrimary(widget.accountId);
      _load();
      widget.onChanged?.call();
      setState(() => _status = 'Primary updated');
    } on Object catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _archive() async {
    final repo = _repoOrNull;
    if (repo == null) {
      setState(() => _error = 'Vault is locked');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      repo.archive(widget.accountId);
      widget.onChanged?.call();
      widget.onClose();
    } on Object catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final account = _account;

    return DecoratedBox(
      key: const Key('page_account_info'),
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
        child: account == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    key: const Key('account_info_back'),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Account not found',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        key: const Key('account_info_back'),
                        onPressed: _busy ? null : widget.onClose,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                      const Spacer(),
                      if (account.isPrimary)
                        Text(
                          'PRIMARY',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.primaryBright,
                            fontFamily: AppTheme.monoFont,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    account.name,
                    key: const Key('account_info_title'),
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance ${formatCents(_repoOrNull?.balanceCents(account.id) ?? account.openingBalanceCents)} · '
                    'Opening ${formatCents(account.openingBalanceCents)} on '
                    '${_dateLabel(account.openingDate)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                      fontFamily: AppTheme.monoFont,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _status!,
                        key: const Key('account_info_status'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryBright,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        _sectionTitle(textTheme, 'Basics'),
                        TextField(
                          key: const Key('account_info_name'),
                          controller: _nameController,
                          enabled: !_busy,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AccountType>(
                          key: const Key('account_info_type'),
                          initialValue: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: [
                            for (final type in AccountType.values)
                              DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: _busy || account.isPrimary
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _type = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_institution'),
                          controller: _institutionController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Institution',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_account_number'),
                          controller: _accountNumberController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Account number',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle(textTheme, 'Credentials'),
                        Text(
                          'Stored only in the encrypted vault. Never written to the audit log.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('account_info_login_url'),
                          controller: _loginUrlController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Login URL',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_login_username'),
                          controller: _loginUsernameController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Login username',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_login_password'),
                          controller: _loginPasswordController,
                          enabled: !_busy,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Login password',
                            suffixIcon: ExcludeFocus(
                              child: IconButton(
                                key: const Key('account_info_toggle_password'),
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle(textTheme, 'Contact'),
                        TextField(
                          key: const Key('account_info_contact_name'),
                          controller: _contactNameController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Contact name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_contact_phone'),
                          controller: _contactPhoneController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Contact phone',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_contact_email'),
                          controller: _contactEmailController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Contact email',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle(textTheme, 'Debt / payment'),
                        TextField(
                          key: const Key('account_info_apr'),
                          controller: _aprController,
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'APR %',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_min_payment'),
                          controller: _minPaymentController,
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\$\.,\-]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Minimum payment',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          key: const Key('account_info_due_day'),
                          initialValue: _dueDay,
                          decoration: const InputDecoration(
                            labelText: 'Payment due day',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('None'),
                            ),
                            for (var day = 1; day <= 31; day++)
                              DropdownMenuItem(
                                value: day,
                                child: Text('$day'),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _dueDay = value),
                        ),
                        CheckboxListTile(
                          key: const Key('account_info_debt_list'),
                          contentPadding: EdgeInsets.zero,
                          value: _includeInDebtList,
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                    () => _includeInDebtList = value ?? false,
                                  ),
                          title: Text(
                            'Include in Debts list',
                            style: textTheme.bodyMedium,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('account_info_notes'),
                          controller: _notesController,
                          enabled: !_busy,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Notes'),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle(textTheme, 'Trends'),
                        Container(
                          key: const Key('account_info_chart_placeholder'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.outline),
                            color: AppColors.surface.withValues(alpha: 0.5),
                          ),
                          child: Text(
                            '12-month balance / interest chart arrives in Phase 4.2.',
                            style: textTheme.bodyMedium?.copyWith(
                              fontFamily: AppTheme.monoFont,
                              color: AppColors.primaryBright,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              key: const Key('account_info_save'),
                              onPressed: _busy ? null : _save,
                              child: const Text('Save'),
                            ),
                            OutlinedButton(
                              key: const Key('account_info_open_register'),
                              onPressed: _busy || widget.onOpenRegister == null
                                  ? null
                                  : () => widget.onOpenRegister!(
                                        widget.accountId,
                                      ),
                              child: const Text('Open register'),
                            ),
                            if (!account.isPrimary &&
                                account.type == AccountType.checking)
                              OutlinedButton(
                                key: const Key('account_info_set_primary'),
                                onPressed: _busy ? null : _setPrimary,
                                child: const Text('Set as primary'),
                              ),
                            if (!account.isPrimary)
                              OutlinedButton(
                                key: const Key('account_info_archive'),
                                onPressed: _busy ? null : _archive,
                                child: Text(
                                  'Archive',
                                  style: TextStyle(color: AppColors.danger),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(color: AppColors.primaryBright),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _centsToEditable(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final rem = (abs % 100).toString().padLeft(2, '0');
    return '$sign$dollars.$rem';
  }
}
