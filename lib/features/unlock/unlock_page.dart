import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../core/app_info.dart';
import '../../data/database_exceptions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

enum UnlockMode { create, unlock }

class UnlockPage extends StatefulWidget {
  const UnlockPage({
    super.key,
    required this.auth,
    required this.mode,
    required this.onUnlocked,
  });

  final AuthService auth;
  final UnlockMode mode;
  final VoidCallback onUnlocked;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _obscure = true;
  bool _forceUnlock = false;
  bool _enableHelloOnCreate = false;
  bool _helloAvailable = false;
  bool _helloEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHelloFlags();
  }

  Future<void> _loadHelloFlags() async {
    try {
      final available = await widget.auth.isHelloAvailable();
      final enabled = widget.mode == UnlockMode.unlock
          ? await widget.auth.isHelloEnabled()
          : false;
      if (!mounted) {
        return;
      }
      setState(() {
        _helloAvailable = available;
        _helloEnabled = enabled;
      });
    } on Object {
      // Platform channel unavailable (tests / missing Hello) — keep defaults.
      if (!mounted) {
        return;
      }
      setState(() {
        _helloAvailable = false;
        _helloEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.mode == UnlockMode.create) {
        await widget.auth.createVault(
          password: _passwordController.text,
          enableHello: _enableHelloOnCreate,
          forceUnlock: _forceUnlock,
        );
      } else {
        await widget.auth.unlockWithPassword(
          password: _passwordController.text,
          forceUnlock: _forceUnlock,
        );
      }
      widget.onUnlocked();
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

  Future<void> _submitHello() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.unlockWithHello(forceUnlock: _forceUnlock);
      widget.onUnlocked();
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

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == UnlockMode.create;
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppInfo.name,
                      key: const Key('unlock_brand'),
                      style: textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCreate ? 'Create vault password' : 'Unlock vault',
                      style: textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCreate
                          ? 'Forgotten passwords cannot be recovered. '
                              'Your data will be permanently inaccessible.'
                          : 'Enter your app password or use Windows Hello.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('password_field'),
                      controller: _passwordController,
                      obscureText: _obscure,
                      enabled: !_busy,
                      textInputAction: isCreate
                          ? TextInputAction.next
                          : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        filled: true,
                        fillColor: AppColors.surface.withValues(alpha: 0.7),
                        suffixIcon: ExcludeFocus(
                          child: IconButton(
                            key: const Key('toggle_password_visibility'),
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a password';
                        }
                        if (isCreate && value.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!isCreate) {
                          _submitPassword();
                        }
                      },
                    ),
                    if (isCreate) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('confirm_password_field'),
                        controller: _confirmController,
                        obscureText: _obscure,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          filled: true,
                          fillColor: AppColors.surface.withValues(alpha: 0.7),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const Key('force_unlock_checkbox'),
                      value: _forceUnlock,
                      onChanged: _busy
                          ? null
                          : (value) =>
                              setState(() => _forceUnlock = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Force unlock if another copy left a lock file',
                        style: textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (isCreate && _helloAvailable)
                      CheckboxListTile(
                        key: const Key('enable_hello_checkbox'),
                        value: _enableHelloOnCreate,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                  () => _enableHelloOnCreate = value ?? false,
                                ),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Enable Windows Hello after create',
                          style: textTheme.bodyMedium,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        key: const Key('unlock_error'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.danger,
                          fontFamily: AppTheme.monoFont,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('password_submit_button'),
                      onPressed: _busy ? null : _submitPassword,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isCreate ? 'Create vault' : 'Unlock'),
                    ),
                    if (!isCreate && _helloEnabled) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('hello_unlock_button'),
                        onPressed: _busy ? null : _submitHello,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock with Windows Hello'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
