import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../core/app_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.helloEnabled,
    required this.helloAvailable,
    required this.onLock,
    required this.onToggleHello,
  });

  final bool helloEnabled;
  final bool helloAvailable;
  final Future<void> Function() onLock;
  final Future<void> Function(bool enable) onToggleHello;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _message;

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Security controls for this session. Database path picker arrives in Phase 0.5.',
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
          ],
        ),
      ),
    );
  }
}
