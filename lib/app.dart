import 'package:flutter/material.dart';

import 'app_shell/app_shell.dart';
import 'core/app_info.dart';
import 'theme/app_theme.dart';

class CashFlowApp extends StatelessWidget {
  const CashFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
