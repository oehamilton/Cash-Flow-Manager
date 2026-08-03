import 'package:flutter/material.dart';

import '../../app_shell/app_shell.dart';
import '../../auth/auth_service.dart';
import '../../auth/vault_switch_service.dart';
import '../../data/account_repository.dart';
import '../../data/audit_categories.dart';
import '../../data/audit_log_repository.dart';
import '../../data/recurrence_materializer.dart';
import '../wizard/setup_wizard_page.dart';
import 'unlock_page.dart';

/// Routes between setup wizard, unlock, and the main shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.auth});

  final AuthService? auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth = widget.auth ?? AuthService();
  bool _loading = true;
  bool _vaultExists = false;
  bool _helloEnabled = false;
  bool _helloAvailable = false;
  bool _needsPrimary = false;
  bool _creatingAdditional = false;
  String? _additionalVaultPath;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final exists = await _auth.vaultExists();
    final helloAvailable = await _auth.isHelloAvailable();
    final helloEnabled = exists ? await _auth.isHelloEnabled() : false;
    var needsPrimary = false;
    if (_auth.isUnlocked) {
      needsPrimary = !AccountRepository(_auth.session!).hasPrimaryAccount();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _vaultExists = exists;
      _helloAvailable = helloAvailable;
      _helloEnabled = helloEnabled;
      _needsPrimary = needsPrimary;
      _loading = false;
    });
  }

  Future<void> _refreshHelloFlags() async {
    final helloEnabled = await _auth.isHelloEnabled();
    final helloAvailable = await _auth.isHelloAvailable();
    if (!mounted) {
      return;
    }
    setState(() {
      _helloEnabled = helloEnabled;
      _helloAvailable = helloAvailable;
    });
  }

  Future<void> _onUnlocked() async {
    final session = _auth.session!;
    final needsPrimary =
        !AccountRepository(session).hasPrimaryAccount();
    if (!needsPrimary) {
      RecurrenceMaterializer(session).materializeAll();
    }
    if (!mounted) {
      return;
    }
    setState(() => _needsPrimary = needsPrimary);
    await _refreshHelloFlags();
  }

  Future<void> _onSetupFinished() async {
    if (!mounted) {
      return;
    }
    // Fresh wizard starts with _vaultExists == false; mark it true so we
    // leave the wizard. Opening an existing vault may still need primary setup.
    final needsPrimary = _auth.isUnlocked &&
        !AccountRepository(_auth.session!).hasPrimaryAccount();
    setState(() {
      _vaultExists = true;
      _needsPrimary = needsPrimary;
      _creatingAdditional = false;
      _additionalVaultPath = null;
    });
    await _refreshHelloFlags();
  }

  Future<void> _lock() async {
    await _auth.lock();
    if (!mounted) {
      return;
    }
    setState(() {
      _needsPrimary = false;
    });
    await _bootstrap();
  }

  /// Settings / Unlock: create another vault at [databasePath].
  Future<void> _beginCreateNewVault(String databasePath) async {
    if (_auth.isUnlocked) {
      await _auth.lock();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingAdditional = true;
      _additionalVaultPath = databasePath;
      _needsPrimary = false;
      _loading = false;
    });
  }

  Future<void> _cancelCreateNewVault() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingAdditional = false;
      _additionalVaultPath = null;
    });
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: Text('Loading…', key: Key('auth_loading'))),
      );
    }

    if (_creatingAdditional) {
      return SetupWizardPage(
        key: const Key('setup_wizard_additional'),
        auth: _auth,
        mode: SetupWizardMode.additional,
        initialDatabasePath: _additionalVaultPath,
        onFinished: _onSetupFinished,
        onCancel: _cancelCreateNewVault,
      );
    }

    if (!_vaultExists) {
      return SetupWizardPage(
        key: const Key('setup_wizard_fresh'),
        auth: _auth,
        mode: SetupWizardMode.fresh,
        onFinished: _onSetupFinished,
      );
    }

    if (!_auth.isUnlocked) {
      return UnlockPage(
        auth: _auth,
        mode: UnlockMode.unlock,
        onUnlocked: _onUnlocked,
        onVaultSwitched: _bootstrap,
        onCreateNewVault: _beginCreateNewVault,
      );
    }

    if (_needsPrimary) {
      return SetupWizardPage(
        key: const Key('setup_wizard_primary_only'),
        auth: _auth,
        mode: SetupWizardMode.primaryOnly,
        onFinished: _onSetupFinished,
      );
    }

    return AppShell(
      auth: _auth,
      onLock: _lock,
      onSwitchVault: _switchVaultAndLock,
      onCreateNewVault: _beginCreateNewVault,
      helloEnabled: _helloEnabled,
      helloAvailable: _helloAvailable,
      onToggleHello: (enable) async {
        if (enable) {
          await _auth.enableHelloUnlock();
        } else {
          await _auth.disableHelloUnlock();
        }
        await _refreshHelloFlags();
      },
    );
  }

  /// Settings: switch active vault pointer, lock, then show unlock for the new file.
  Future<void> _switchVaultAndLock(String databasePath) async {
    final session = _auth.session;
    if (session != null) {
      AuditLogRepository(session).append(
        category: AuditCategory.settings,
        action: AuditAction.switchVault,
        summary: 'Switched active vault',
        entityType: AuditEntityType.vault,
        detail: {'to': databasePath},
      );
    }
    await VaultSwitchService.activate(databasePath);
    await _auth.lock();
    if (!mounted) {
      return;
    }
    setState(() => _needsPrimary = false);
    await _bootstrap();
  }
}
