import 'package:flutter/material.dart';

import '../../app_shell/app_shell.dart';
import '../../auth/auth_service.dart';
import 'unlock_page.dart';

/// Routes between create-password, unlock, and the main shell.
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final exists = await _auth.vaultExists();
    final helloAvailable = await _auth.isHelloAvailable();
    final helloEnabled = exists ? await _auth.isHelloEnabled() : false;
    if (!mounted) {
      return;
    }
    setState(() {
      _vaultExists = exists;
      _helloAvailable = helloAvailable;
      _helloEnabled = helloEnabled;
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

  void _onUnlocked() {
    setState(() {});
    _refreshHelloFlags();
  }

  Future<void> _lock() async {
    await _auth.lock();
    if (!mounted) {
      return;
    }
    setState(() {});
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Non-animating placeholder so widget tests can pump without hanging
      // on an indeterminate CircularProgressIndicator ticker.
      return const Scaffold(
        body: Center(child: Text('Loading…', key: Key('auth_loading'))),
      );
    }

    if (_auth.isUnlocked) {
      return AppShell(
        onLock: _lock,
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

    return UnlockPage(
      auth: _auth,
      mode: _vaultExists ? UnlockMode.unlock : UnlockMode.create,
      onUnlocked: _onUnlocked,
    );
  }
}
