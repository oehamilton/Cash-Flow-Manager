import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'features/unlock/auth_gate.dart';
import 'theme/app_theme.dart';

class CashFlowApp extends StatelessWidget {
  const CashFlowApp({super.key, this.authGate});

  /// Optional override for tests.
  final Widget? authGate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: authGate ?? const AuthGate(),
    );
  }
}
