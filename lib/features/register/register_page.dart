import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Register surface for a selected account (ledger UI arrives in Phase 2).
class RegisterPage extends StatelessWidget {
  const RegisterPage({
    super.key,
    required this.auth,
    required this.accountId,
  });

  final AuthService? auth;
  final String? accountId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = auth?.session;
    Account? account;
    var balanceCents = 0;
    if (session != null && accountId != null) {
      final repo = AccountRepository(session);
      account = repo.getById(accountId!);
      if (account != null) {
        balanceCents = repo.balanceCents(account.id);
      }
    }

    return DecoratedBox(
      key: const Key('page_register'),
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
            Text(
              account == null ? 'Register' : 'Register — ${account.name}',
              key: const Key('register_title'),
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (account == null)
              Text(
                session == null
                    ? 'Unlock a vault to open a register.'
                    : 'No account selected. Cold start opens primary checking when available.',
                key: const Key('register_empty'),
                style: textTheme.bodyLarge,
              )
            else ...[
              Text(
                '${account.type.label}'
                '${account.isPrimary ? ' · PRIMARY' : ''}'
                '${account.institution == null || account.institution!.isEmpty ? '' : ' · ${account.institution}'}',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Balance',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontFamily: AppTheme.monoFont,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCents(balanceCents),
                key: const Key('register_balance'),
                style: textTheme.headlineSmall?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: balanceCents < 0
                      ? AppColors.danger
                      : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outline),
                  color: AppColors.surface.withValues(alpha: 0.6),
                ),
                child: Text(
                  '// phase 2 — transactions, clear, running balance',
                  key: const Key('register_phase_hint'),
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: AppTheme.monoFont,
                    color: AppColors.primaryBright,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
