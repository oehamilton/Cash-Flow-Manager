import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../auth/auth_service.dart';
import '../../auth/vault_files.dart';
import '../../auth/vault_paths.dart';
import '../../core/app_info.dart';
import '../../data/account_repository.dart';
import '../../data/database_exceptions.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'setup_coordinator.dart';

enum SetupWizardMode {
  /// First-run wizard (welcome → location → security → checking).
  fresh,

  /// Unlocked vault missing a primary checking account.
  primaryOnly,

  /// Create another vault while one already exists (location → security → checking).
  additional,
}

class SetupWizardPage extends StatefulWidget {
  const SetupWizardPage({
    super.key,
    required this.auth,
    required this.mode,
    required this.onFinished,
    this.onCancel,
    this.initialDatabasePath,
  });

  final AuthService auth;
  final SetupWizardMode mode;
  final VoidCallback onFinished;

  /// Optional escape for [SetupWizardMode.additional].
  final VoidCallback? onCancel;

  /// Prefills the vault path (used by additional-vault flow).
  final String? initialDatabasePath;

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  late final SetupCoordinator _coordinator = SetupCoordinator(widget.auth);
  late int _step;

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pathController = TextEditingController();
  final _nameController = TextEditingController(text: 'Checking');
  final _institutionController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');

  DateTime _openingDate = DateTime.now();
  bool _obscure = true;
  bool _enableHello = false;
  bool _forceUnlock = false;
  bool _helloAvailable = false;
  bool _busy = false;
  String? _error;
  VaultPresence _presence = VaultPresence.none;
  VaultSetupAction _action = VaultSetupAction.create;

  static const _freshSteps = [
    'Welcome',
    'Location',
    'Security',
    'Checking',
  ];

  bool get _isOpenAction => _action == VaultSetupAction.open;

  bool get _isFreshLike =>
      widget.mode == SetupWizardMode.fresh ||
      widget.mode == SetupWizardMode.additional;

  @override
  void initState() {
    super.initState();
    _step = switch (widget.mode) {
      SetupWizardMode.fresh => 0,
      SetupWizardMode.additional => 1,
      SetupWizardMode.primaryOnly => 3,
    };
    _pathController.addListener(_onPathEdited);
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final hello = await widget.auth.isHelloAvailable();
    final initial = widget.initialDatabasePath?.trim();
    final defaultPath = (initial != null && initial.isNotEmpty)
        ? initial
        : widget.mode == SetupWizardMode.additional
            ? VaultPaths.suggestedNewVaultDatabasePath()
            : await VaultPaths.defaultDatabasePath();
    if (!mounted) {
      return;
    }
    _pathController.text = defaultPath;
    setState(() => _helloAvailable = hello);
    await _refreshPresence();
  }

  void _onPathEdited() {
    _refreshPresence();
  }

  Future<void> _refreshPresence() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _presence = VaultPresence.none;
        _action = VaultSetupAction.create;
      });
      return;
    }
    final presence = await widget.auth.vaultPresenceAt(path);
    if (!mounted) {
      return;
    }
    setState(() {
      _presence = presence;
      switch (presence) {
        case VaultPresence.none:
          _action = VaultSetupAction.create;
        case VaultPresence.complete:
          if (_action == VaultSetupAction.create) {
            _action = VaultSetupAction.open;
          }
        case VaultPresence.incomplete:
          _action = VaultSetupAction.overwrite;
      }
    });
  }

  @override
  void dispose() {
    _pathController.removeListener(_onPathEdited);
    _passwordController.dispose();
    _confirmController.dispose();
    _pathController.dispose();
    _nameController.dispose();
    _institutionController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  bool get _isLastStep {
    if (widget.mode == SetupWizardMode.primaryOnly) {
      return true;
    }
    if (_isOpenAction) {
      return _step >= 2;
    }
    return _step >= 3;
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_isFreshLike) {
      if (_step == 1) {
        if (!await _validateLocation()) {
          return;
        }
        setState(() => _step += 1);
        return;
      }
      if (_step == 2) {
        if (!_validateSecurity()) {
          return;
        }
        if (_isOpenAction) {
          await _finish();
          return;
        }
        setState(() => _step += 1);
        return;
      }
      if (_step == 3) {
        await _finish();
        return;
      }
      setState(() => _step += 1);
      return;
    }
    await _finish();
  }

  void _back() {
    if (widget.mode == SetupWizardMode.primaryOnly) {
      return;
    }
    if (widget.mode == SetupWizardMode.additional && _step <= 1) {
      widget.onCancel?.call();
      return;
    }
    if (_step == 0) {
      return;
    }
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  Future<bool> _validateLocation() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Enter a database file path');
      return false;
    }
    if (!path.toLowerCase().endsWith('.cfm.db') &&
        !path.toLowerCase().endsWith('.db')) {
      setState(
        () => _error =
            'Path should be a database file (e.g. ...\\vault.cfm.db)',
      );
      return false;
    }

    await _refreshPresence();
    if (_presence == VaultPresence.complete &&
        _action != VaultSetupAction.open &&
        _action != VaultSetupAction.overwrite) {
      setState(
        () => _error = 'Choose Open existing vault or Overwrite below',
      );
      return false;
    }
    if (_presence == VaultPresence.incomplete &&
        _action != VaultSetupAction.overwrite) {
      setState(
        () => _error =
            'This path has incomplete vault files. Choose Overwrite to replace them.',
      );
      return false;
    }
    if (_action == VaultSetupAction.overwrite &&
        _presence != VaultPresence.none) {
      final confirmed = await _confirmOverwrite();
      if (!confirmed) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _confirmOverwrite() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('wizard_overwrite_dialog'),
        title: const Text('Overwrite existing vault?'),
        content: const Text(
          'This permanently deletes the existing database at this path '
          'and creates a new empty vault. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('wizard_overwrite_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool _validateSecurity() {
    final password = _passwordController.text;
    if (_isOpenAction) {
      if (password.isEmpty) {
        setState(() => _error = 'Enter the vault password');
        return false;
      }
      return true;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return false;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return false;
    }
    return true;
  }

  PrimaryCheckingDraft? _buildPrimaryDraft() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Account name is required');
      return null;
    }
    try {
      final cents = parseDollarsToCents(_balanceController.text);
      return PrimaryCheckingDraft(
        name: name,
        institution: _institutionController.text.trim().isEmpty
            ? null
            : _institutionController.text.trim(),
        openingBalanceCents: cents,
        openingDate: _openingDate,
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return null;
    }
  }

  Future<void> _finish() async {
    PrimaryCheckingDraft? draft;
    if (!_isOpenAction || widget.mode == SetupWizardMode.primaryOnly) {
      draft = _buildPrimaryDraft();
      if (draft == null) {
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isFreshLike) {
        await _coordinator.completeFreshSetup(
          databasePath: _pathController.text.trim(),
          password: _passwordController.text,
          enableHello: _enableHello,
          forceUnlock: _forceUnlock,
          action: _action,
          primary: draft,
        );
      } else {
        await _coordinator.completePrimaryOnly(draft!);
      }
      widget.onFinished();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on DatabaseLockedException catch (e) {
      setState(() => _error = e.message);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickOpeningDate() async {
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

  Future<void> _browseForVaultPath() async {
    final current = _pathController.text.trim();
    final initialDirectory = current.isEmpty ? null : p.dirname(current);
    const typeGroup = XTypeGroup(
      label: 'Cash Flow Manager vault',
      extensions: <String>['cfm.db', 'db'],
    );
    final location = await getSaveLocation(
      acceptedTypeGroups: const [typeGroup],
      suggestedName: current.isEmpty
          ? VaultPaths.defaultFileName
          : p.basename(current),
      initialDirectory: initialDirectory,
      confirmButtonText: 'Select',
    );
    if (location == null || !mounted) {
      return;
    }
    _pathController.text = location.path;
    await _refreshPresence();
  }

  Future<void> _browseOpenExisting() async {
    final current = _pathController.text.trim();
    final initialDirectory = current.isEmpty ? null : p.dirname(current);
    const typeGroup = XTypeGroup(
      label: 'Cash Flow Manager vault',
      extensions: <String>['cfm.db', 'db'],
    );
    final file = await openFile(
      acceptedTypeGroups: const [typeGroup],
      initialDirectory: initialDirectory,
      confirmButtonText: 'Open',
    );
    if (file == null || !mounted) {
      return;
    }
    _pathController.text = file.path;
    await _refreshPresence();
    if (_presence == VaultPresence.complete) {
      setState(() => _action = VaultSetupAction.open);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppInfo.name,
                    key: const Key('wizard_brand'),
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (widget.mode) {
                      SetupWizardMode.fresh =>
                        'Setup wizard — ${_freshSteps[_step.clamp(0, 3)]}',
                      SetupWizardMode.additional =>
                        'New vault — ${_freshSteps[_step.clamp(0, 3)]}',
                      SetupWizardMode.primaryOnly =>
                        'Finish setup — Primary checking',
                    },
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: _buildStepBody(textTheme)),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('wizard_error'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                        fontFamily: AppTheme.monoFont,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_isFreshLike &&
                          (_step > 0 ||
                              widget.mode == SetupWizardMode.additional))
                        OutlinedButton(
                          key: const Key('wizard_back'),
                          onPressed: _busy ? null : _back,
                          child: Text(
                            widget.mode == SetupWizardMode.additional &&
                                    _step <= 1
                                ? 'Cancel'
                                : 'Back',
                          ),
                        ),
                      const Spacer(),
                      FilledButton(
                        key: const Key('wizard_next'),
                        onPressed: _busy ? null : _next,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isLastStep
                                    ? (_isOpenAction ? 'Open vault' : 'Finish')
                                    : 'Next',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(TextTheme textTheme) {
    if (widget.mode == SetupWizardMode.primaryOnly || _step == 3) {
      return _primaryStep(textTheme);
    }
    return switch (_step) {
      0 => _welcomeStep(textTheme),
      1 => _locationStep(textTheme),
      2 => _securityStep(textTheme),
      _ => _primaryStep(textTheme),
    };
  }

  Widget _welcomeStep(TextTheme textTheme) {
    return Column(
      key: const Key('wizard_step_welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Cash Flow Manager keeps a local encrypted bank register and '
          'short-horizon forecast so you can see today’s balance and the '
          'next several weeks before you spend or pay extra on debt.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Next you will choose where to store the vault, set a password, '
          'and create your primary checking account.',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _locationStep(TextTheme textTheme) {
    return ListView(
      key: const Key('wizard_step_location'),
      children: [
        Text('Database location', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Choose where the encrypted vault file is stored. '
          'A OneDrive folder works if you keep it synced before opening.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('wizard_path_field'),
          controller: _pathController,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: 'Vault file path',
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.7),
            suffixIcon: ExcludeFocus(
              child: IconButton(
                key: const Key('wizard_browse_path'),
                tooltip: 'Browse for new location…',
                onPressed: _busy ? null : _browseForVaultPath,
                icon: const Icon(Icons.folder_open_outlined),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              key: const Key('wizard_browse_path_button'),
              onPressed: _busy ? null : _browseForVaultPath,
              child: const Text('Browse new…'),
            ),
            TextButton(
              key: const Key('wizard_open_existing_button'),
              onPressed: _busy ? null : _browseOpenExisting,
              child: const Text('Open existing…'),
            ),
            TextButton(
              key: const Key('wizard_use_default_path'),
              onPressed: _busy
                  ? null
                  : () async {
                      final path = await VaultPaths.defaultDatabasePath();
                      _pathController.text = path;
                      await _refreshPresence();
                    },
              child: const Text('Use default AppData location'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Missing folders are created automatically when you create a vault.',
          style: textTheme.bodySmall,
        ),
        if (_presence != VaultPresence.none) ...[
          const SizedBox(height: 20),
          Text('Vault already found at this path', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_presence == VaultPresence.incomplete)
            Text(
              'Files look incomplete. Overwrite to replace them with a new vault.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.warning),
            ),
          if (_presence == VaultPresence.complete)
            RadioGroup<VaultSetupAction>(
              groupValue: _action,
              onChanged: _busy
                  ? (_) {}
                  : (value) {
                      if (value != null) {
                        setState(() => _action = value);
                      }
                    },
              child: Column(
                children: [
                  RadioListTile<VaultSetupAction>(
                    key: const Key('wizard_action_open'),
                    value: VaultSetupAction.open,
                    title: Text(
                      'Open existing vault',
                      style: textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Unlock with its password. No data is deleted.',
                      style: textTheme.bodySmall,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<VaultSetupAction>(
                    key: const Key('wizard_action_overwrite'),
                    value: VaultSetupAction.overwrite,
                    title: Text(
                      'Overwrite with a new vault',
                      style: textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Permanently deletes the existing database, then creates a new one.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          if (_presence == VaultPresence.incomplete)
            RadioGroup<VaultSetupAction>(
              groupValue: _action,
              onChanged: _busy
                  ? (_) {}
                  : (value) {
                      if (value != null) {
                        setState(() => _action = value);
                      }
                    },
              child: RadioListTile<VaultSetupAction>(
                key: const Key('wizard_action_overwrite_incomplete'),
                value: VaultSetupAction.overwrite,
                title: Text(
                  'Overwrite incomplete vault',
                  style: textTheme.bodyMedium,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ],
    );
  }

  Widget _securityStep(TextTheme textTheme) {
    return ListView(
      key: const Key('wizard_step_security'),
      children: [
        Text(
          _isOpenAction ? 'Unlock vault' : 'Security',
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          _isOpenAction
              ? 'Enter the password for the existing vault.'
              : 'Forgotten passwords cannot be recovered. '
                  'Your data will be permanently inaccessible.',
          style: textTheme.bodyMedium?.copyWith(
            color: _isOpenAction ? null : AppColors.warning,
          ),
        ),
        if (_action == VaultSetupAction.overwrite) ...[
          const SizedBox(height: 8),
          Text(
            'You chose overwrite. Set a password for the new vault.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('wizard_password_field'),
          controller: _passwordController,
          obscureText: _obscure,
          enabled: !_busy,
          textInputAction:
              _isOpenAction ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (_isOpenAction) {
              _next();
            }
          },
          decoration: InputDecoration(
            labelText: _isOpenAction ? 'Vault password' : 'Password',
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.7),
            suffixIcon: ExcludeFocus(
              child: IconButton(
                key: const Key('wizard_toggle_password'),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ),
        if (!_isOpenAction) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('wizard_confirm_field'),
            controller: _confirmController,
            obscureText: _obscure,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.7),
            ),
          ),
        ],
        CheckboxListTile(
          key: const Key('wizard_force_unlock'),
          value: _forceUnlock,
          onChanged: _busy
              ? null
              : (value) => setState(() => _forceUnlock = value ?? false),
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Force unlock if a leftover lock file exists',
            style: textTheme.bodyMedium,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (!_isOpenAction && _helloAvailable)
          CheckboxListTile(
            key: const Key('wizard_enable_hello'),
            value: _enableHello,
            onChanged: _busy
                ? null
                : (value) => setState(() => _enableHello = value ?? false),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Enable Windows Hello after create',
              style: textTheme.bodyMedium,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    );
  }

  Widget _primaryStep(TextTheme textTheme) {
    final dateLabel =
        '${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')}';

    return ListView(
      key: const Key('wizard_step_primary'),
      children: [
        Text('Primary checking account', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'This is the main register used for cash-flow forecasting.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('wizard_account_name'),
          controller: _nameController,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: 'Account name',
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('wizard_institution'),
          controller: _institutionController,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: 'Institution (optional)',
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('wizard_opening_balance'),
          controller: _balanceController,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\$\.,\-]')),
          ],
          decoration: InputDecoration(
            labelText: 'Opening balance',
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          key: const Key('wizard_opening_date'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Opening date'),
          subtitle: Text(dateLabel),
          trailing: OutlinedButton(
            onPressed: _busy ? null : _pickOpeningDate,
            child: const Text('Change'),
          ),
        ),
      ],
    );
  }
}
