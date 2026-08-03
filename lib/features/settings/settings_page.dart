import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../auth/auth_service.dart';
import '../../auth/vault_backup_service.dart';
import '../../auth/vault_switch_service.dart';
import '../../core/app_info.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/app_settings_repository.dart';
import '../../data/audit_categories.dart';
import '../../data/audit_log_repository.dart';
import '../../data/register_csv_exporter.dart';
import '../../data/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../about/about_dialog.dart';
import '../vault/vault_create_flow.dart';
import '../vault/vault_file_picker.dart';
import '../vault/vault_restore_flow.dart';
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
    this.onSwitchVault,
    this.onCreateNewVault,
  });

  final AuthService? auth;
  final bool helloEnabled;
  final bool helloAvailable;
  final String? databasePath;
  final int lockTimeoutMinutes;
  final Future<void> Function() onLock;
  final Future<void> Function(bool enable) onToggleHello;
  final Future<void> Function(int minutes)? onLockTimeoutChanged;

  /// Switch to another vault file and return to the unlock screen.
  final Future<void> Function(String databasePath)? onSwitchVault;

  /// Start the create-another-vault wizard at [databasePath].
  final Future<void> Function(String databasePath)? onCreateNewVault;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  late int _lockTimeoutMinutes;
  int _auditRetentionDays = 365;
  String? _exportAccountId;

  static const _timeoutChoices = <int>[
    0, // never
    5,
    15,
    30,
    60,
  ];

  static const _retentionChoices = <int>[
    90,
    365,
    730,
    0, // forever
  ];

  @override
  void initState() {
    super.initState();
    _lockTimeoutMinutes = widget.lockTimeoutMinutes;
    _loadAuditRetention();
  }

  void _loadAuditRetention() {
    final session = widget.auth?.session;
    if (session == null) {
      _auditRetentionDays = 365;
      return;
    }
    _auditRetentionDays =
        AppSettingsRepository(session).auditRetentionDays();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lockTimeoutMinutes != widget.lockTimeoutMinutes) {
      _lockTimeoutMinutes = widget.lockTimeoutMinutes;
    }
    if (oldWidget.auth?.session != widget.auth?.session) {
      _loadAuditRetention();
    }
  }

  static String _retentionLabel(int days) {
    return switch (days) {
      0 => 'Forever',
      90 => '90 days',
      365 => '1 year',
      730 => '2 years',
      _ => '$days days',
    };
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await action();
    } on AuthException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } on Object catch (e) {
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
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

  Future<void> _openDifferentVault() async {
    final switchVault = widget.onSwitchVault;
    if (switchVault == null) {
      throw StateError('Vault switching is unavailable');
    }
    final initial = widget.databasePath != null
        ? p.dirname(widget.databasePath!)
        : await activeVaultInitialDirectory();
    final picked = await pickExistingVaultPath(initialDirectory: initial);
    if (picked == null) {
      return;
    }
    // Validate before tearing down the session; AuthGate activates + locks.
    final path = await VaultSwitchService.ensureComplete(picked);
    await switchVault(path);
  }

  Future<void> _restoreVault() async {
    final switchVault = widget.onSwitchVault;
    if (switchVault == null) {
      throw StateError('Vault restore is unavailable');
    }
    final restored = await runRestoreVaultFlow(context);
    if (restored == null) {
      return;
    }
    final session = widget.auth?.session;
    if (session != null) {
      AuditLogRepository(session).append(
        category: AuditCategory.settings,
        action: AuditAction.restoreVault,
        summary: 'Restored vault from backup',
        entityType: AuditEntityType.vault,
        detail: {'to': restored},
      );
    }
    await switchVault(restored);
  }

  Future<void> _createNewVault() async {
    final createNew = widget.onCreateNewVault;
    if (createNew == null) {
      throw StateError('Create new vault is unavailable');
    }
    final path = await runCreateNewVaultFlow(context);
    if (path == null) {
      return;
    }
    final session = widget.auth?.session;
    if (session != null) {
      AuditLogRepository(session).append(
        category: AuditCategory.settings,
        action: AuditAction.createVault,
        summary: 'Started create new vault wizard',
        entityType: AuditEntityType.vault,
        detail: {'to': path},
      );
    }
    await createNew(path);
  }

  Future<void> _backupVault() async {
    final source = widget.databasePath;
    final session = widget.auth?.session;
    if (source == null || session == null) {
      throw StateError('Unlock the vault before backing up');
    }

    const typeGroup = XTypeGroup(
      label: 'Cash Flow Manager vault',
      extensions: <String>['cfm.db', 'db'],
    );
    final location = await getSaveLocation(
      acceptedTypeGroups: const [typeGroup],
      suggestedName: VaultBackupService.suggestedFileName(),
      initialDirectory: p.dirname(source),
      confirmButtonText: 'Backup',
    );
    if (location == null) {
      return;
    }

    await VaultBackupService.backupEncryptedVault(
      sourceDatabasePath: source,
      destDatabasePath: location.path,
    );
    AuditLogRepository(session).append(
      category: AuditCategory.settings,
      action: AuditAction.backupVault,
      summary: 'Backed up encrypted vault',
      entityType: AuditEntityType.vault,
      detail: {'dest': location.path},
    );
    if (mounted) {
      setState(() {
        _message = 'Vault backed up to ${location.path}';
        _messageIsError = false;
      });
    }
  }

  Future<void> _exportRegisterCsv() async {
    final session = widget.auth?.session;
    if (session == null) {
      throw StateError('Unlock the vault before exporting');
    }
    final accounts = AccountRepository(session).listAccounts();
    if (accounts.isEmpty) {
      throw StateError('No accounts to export');
    }
    final accountId = _exportAccountId ??
        accounts.firstWhere((a) => a.isPrimary, orElse: () => accounts.first).id;
    final account = accounts.firstWhere((a) => a.id == accountId);
    final entries =
        TransactionRepository(session).listRegisterEntries(account.id);

    const typeGroup = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv'],
    );
    final location = await getSaveLocation(
      acceptedTypeGroups: const [typeGroup],
      suggestedName: RegisterCsvExporter.suggestedFileName(account.name),
      confirmButtonText: 'Export',
    );
    if (location == null) {
      return;
    }

    final csv = RegisterCsvExporter.export(entries);
    await File(location.path).writeAsString(csv);
    AuditLogRepository(session).append(
      category: AuditCategory.settings,
      action: AuditAction.exportCsv,
      summary: 'Exported register CSV for "${account.name}"',
      entityType: AuditEntityType.account,
      entityId: account.id,
      detail: {
        'dest': location.path,
        'rows': entries.length,
      },
    );
    if (mounted) {
      setState(() {
        _message =
            'Exported ${entries.length} rows to ${location.path}';
        _messageIsError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = widget.auth?.session;
    final accounts = session == null
        ? const <Account>[]
        : AccountRepository(session).listAccounts();
    final exportValue = accounts.any((a) => a.id == _exportAccountId)
        ? _exportAccountId
        : (accounts.where((a) => a.isPrimary).map((a) => a.id).firstOrNull ??
            accounts.firstOrNull?.id);

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
                'Security, backup, and activity for this vault.',
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
              const SizedBox(height: 16),
              Text('About', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'A ${AppInfo.companyName} product · ${AppInfo.supportEmail}',
                key: const Key('settings_about_preview'),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('settings_about_button'),
                onPressed: () => showAboutAppDialog(context),
                child: const Text('About'),
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
                const SizedBox(height: 8),
                Text(
                  'Switch to another encrypted vault (e.g. personal vs business). '
                  'You will lock and unlock with that vault\'s password.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('settings_open_different_vault'),
                  onPressed: (_busy || widget.onSwitchVault == null)
                      ? null
                      : () => _run(_openDifferentVault),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open different vault…'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('settings_create_new_vault'),
                  onPressed: (_busy || widget.onCreateNewVault == null)
                      ? null
                      : () => _run(_createNewVault),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Create new vault…'),
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
              const SizedBox(height: 32),
              Text('Backup & export', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Backup keeps the encrypted vault (database + meta). '
                'Restore copies a backup into Documents\\CashFlowManager\\Restored '
                '(recommended), then switches to it. '
                'CSV is a plain-text register export for one account.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('settings_backup_vault'),
                onPressed: (_busy || session == null || widget.databasePath == null)
                    ? null
                    : () => _run(_backupVault),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Backup vault…'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('settings_restore_vault'),
                onPressed: (_busy || widget.onSwitchVault == null)
                    ? null
                    : () => _run(_restoreVault),
                icon: const Icon(Icons.settings_backup_restore_outlined),
                label: const Text('Restore vault from backup…'),
              ),
              const SizedBox(height: 16),
              if (accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: const Key('settings_export_account'),
                  initialValue: exportValue,
                  decoration: const InputDecoration(
                    labelText: 'Account for CSV export',
                  ),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _exportAccountId = value),
                ),
              if (accounts.isNotEmpty) const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('settings_export_csv'),
                onPressed: (_busy || session == null || accounts.isEmpty)
                    ? null
                    : () => _run(_exportRegisterCsv),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export register CSV…'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  key: const Key('settings_status'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: _messageIsError
                        ? AppColors.danger
                        : AppColors.primaryBright,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text('Activity log', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Read-only trail of unlocks and data changes by device. '
                'Secrets are never stored. Older events are removed per '
                'retention (default 1 year).',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: Key('settings_audit_retention_$_auditRetentionDays'),
                initialValue: _retentionChoices.contains(_auditRetentionDays)
                    ? _auditRetentionDays
                    : 365,
                decoration: const InputDecoration(
                  labelText: 'Activity log retention',
                  helperText: 'Events older than this are deleted on unlock.',
                ),
                items: [
                  for (final days in _retentionChoices)
                    DropdownMenuItem(
                      value: days,
                      child: Text(_retentionLabel(days)),
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
                          settings.setAuditRetentionDays(value);
                          final removed = AuditLogRepository(session)
                              .applyRetention(value);
                          AuditLogRepository(session).append(
                            category: AuditCategory.settings,
                            action: AuditAction.update,
                            summary: value <= 0
                                ? 'Set activity log retention to forever'
                                : 'Set activity log retention to '
                                    '${_retentionLabel(value)}',
                            detail: {
                              'audit_retention_days': value,
                              'pruned_rows': removed,
                            },
                          );
                          setState(() => _auditRetentionDays = value);
                        });
                      },
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
