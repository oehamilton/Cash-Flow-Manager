import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../theme/app_colors.dart';
import '../settings/payees_panel.dart';

/// Full-page payee directory (left-rail destination).
class PayeesPage extends StatelessWidget {
  const PayeesPage({super.key, required this.auth});

  final AuthService? auth;

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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payees',
                key: const Key('payees_page_title'),
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Directory for vendors and people. Choose an account as payee '
                'in the register to transfer between accounts.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              PayeesPanel(auth: auth),
            ],
          ),
        ),
      ),
    );
  }
}
