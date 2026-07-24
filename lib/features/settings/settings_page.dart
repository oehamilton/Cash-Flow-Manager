import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../core/app_info.dart';
import '../../data/app_settings_repository.dart';
import '../../data/audit_categories.dart';
import '../../data/audit_log_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'activity_log_panel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.helloEnabled,
    required this.helloAvailable,
    required this.onLock,
    required this.onToggleHello,
    this.auth,
    this.databasePath,
    this.lockTimeoutMinutes = 15,
    this.onLockTimeoutChanged,
  });

  final AuthService? auth;
  final bool helloEnabled;
  final bool helloAvailable;
  final String? databasePath;
  final int lockTimeoutMinutes;
  final Future<void> Function() onLock;
  final Future<void> Function(bool enable) onToggleHello;
  final Future<void> Function(int minutes)? onLockTimeoutChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _message;
  late int _lockTimeoutMinutes;

  static const _timeoutChoices = <int>[
    0, // never
    5,
    15,
    30,
    60,
  ];

  @override
  void initState() {
    super.initState();
    _lockTimeoutMinutes = widget.lockTimeoutMinutes;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lockTimeoutMinutes != widget.lockTimeoutMinutes) {
      _lockTimeoutMinutes = widget.lockTimeoutMinutes;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      setState(() => _message = e.message);
    } on Object catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _timeoutLabel(int minutes) {
    if (minutes <= 0) {
      return 'Never';
    }
    if (minutes == 60) {
      return '60 minutes';
    }
    return '$minutes minutes';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = widget.auth?.session;

    return DecoratedBox(
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Security, idle lock, and activity for this vault.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                'App ${AppInfo.versionLabel}',
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: AppColors.primaryBright,
                ),
              ),
              if (widget.databasePath != null) ...[
                const SizedBox(height: 8),
                Text('Vault', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                SelectableText(
                  widget.databasePath!,
                  key: const Key('settings_db_path'),
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: AppTheme.monoFont,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SwitchListTile(
                key: const Key('hello_toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Windows Hello unlock'),
                subtitle: Text(
                  widget.helloAvailable
                      ? 'Unlock with Windows Hello after biometric / PIN confirmation.'
                      : 'Windows Hello is not available on this device.',
                ),
                value: widget.helloEnabled,
                onChanged: (!_busy && widget.helloAvailable)
                    ? (value) => _run(() => widget.onToggleHello(value))
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: Key('settings_lock_timeout_$_lockTimeoutMinutes'),
                initialValue: _timeoutChoices.contains(_lockTimeoutMinutes)
                    ? _lockTimeoutMinutes
                    : 15,
                decoration: const InputDecoration(
                  labelText: 'Idle lock',
                  helperText:
                      'Automatically lock the vault after no mouse or keyboard activity.',
                ),
                items: [
                  for (final minutes in _timeoutChoices)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(_timeoutLabel(minutes)),
                    ),
                ],
                onChanged: (_busy || session == null)
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        _run(() async {
                          final settings = AppSettingsRepository(session);
                          settings.setLockTimeoutMinutes(value);
                          AuditLogRepository(session).append(
                            category: AuditCategory.settings,
                            action: AuditAction.update,
                            summary: value <= 0
                                ? 'Disabled idle lock'
                                : 'Set idle lock to $value minutes',
                            detail: {'lock_timeout_minutes': value},
                          );
                          setState(() => _lockTimeoutMinutes = value);
                          await widget.onLockTimeoutChanged?.call(value);
                        });
                      },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('lock_button'),
                onPressed: _busy ? null : () => _run(widget.onLock),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock vault'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 32),
              Text('Activity log', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Read-only trail of unlocks and data changes by device. '
                'Secrets are never stored.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 12),
              ActivityLogPanel(session: session),
            ],
          ),
        ),
      ),
    );
  }
}
