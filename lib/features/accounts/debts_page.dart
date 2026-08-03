import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/extra_payment_hint.dart';
import '../../data/money.dart';
import '../../data/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'account_info_page.dart';
import 'extra_payment_banner.dart';

/// Debt-focused list: balance, APR, and payment (Phase 1.2).
class DebtsPage extends StatefulWidget {
  const DebtsPage({
    super.key,
    required this.auth,
    this.onOpenRegister,
  });

  final AuthService? auth;
  final ValueChanged<String>? onOpenRegister;

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  List<AccountSummary> _rows = const [];
  ExtraPaymentHint? _hint;
  String? _error;
  bool _loading = true;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  @override
  void didUpdateWidget(covariant DebtsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth?.session != widget.auth?.session) {
      _selectedAccountId = null;
      _reload();
    }
  }

  void _reload({bool initial = false}) {
    final session = widget.auth?.session;
    List<AccountSummary> rows = const [];
    ExtraPaymentHint? hint;
    String? error;
    if (session == null) {
      rows = const [];
    } else {
      try {
        final accounts = AccountRepository(session);
        rows = accounts.listSummaries(debtsOnly: true);
        final primaryId = accounts.primaryAccountId();
        if (primaryId != null) {
          final primary = accounts.getById(primaryId);
          final metrics = TransactionRepository(session).metricsFor(primaryId);
          hint = ExtraPaymentHint.fromPrimary(
            primaryMetrics: metrics,
            debts: rows,
            minBalanceCents: primary?.minBalanceCents ?? 0,
          );
        }
      } on Object catch (e) {
        error = e.toString();
      }
    }
    if (initial) {
      _rows = rows;
      _hint = hint;
      _error = error;
      _loading = false;
      return;
    }
    setState(() {
      _rows = rows;
      _hint = hint;
      _error = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    if (_selectedAccountId != null && auth?.session != null) {
      return AccountInfoPage(
        auth: auth!,
        accountId: _selectedAccountId!,
        onClose: () => setState(() => _selectedAccountId = null),
        onChanged: _reload,
        onOpenRegister: widget.onOpenRegister == null
            ? null
            : (accountId) {
                setState(() => _selectedAccountId = null);
                widget.onOpenRegister!(accountId);
              },
      );
    }

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debts',
              key: const Key('debts_title'),
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a debt for details. Sorted by APR (highest first).',
              style: textTheme.bodyLarge,
            ),
            if (_hint != null) ...[
              const SizedBox(height: 16),
              ExtraPaymentBanner(hint: _hint!),
            ],
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_rows.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    widget.auth?.session == null
                        ? 'Unlock a vault to view debts.'
                        : 'No debt accounts yet.',
                    key: const Key('debts_empty'),
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    _header(textTheme),
                    const Divider(height: 1, color: AppColors.outline),
                    Expanded(
                      child: ListView.separated(
                        key: const Key('debts_list'),
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.outline,
                        ),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final targetId = _hint?.targetDebt?.account.id;
                          return _DebtRow(
                            summary: row,
                            suggested: targetId == row.account.id,
                            onTap: () => setState(
                              () => _selectedAccountId = row.account.id,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(TextTheme textTheme) {
    final style = textTheme.labelLarge?.copyWith(
      color: AppColors.onSurfaceMuted,
      fontFamily: AppTheme.monoFont,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(
            flex: 2,
            child: Text('Balance', style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            child: Text('APR', style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Text('Min payment', style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            child: Text('Due', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.summary,
    required this.onTap,
    this.suggested = false,
  });

  final AccountSummary summary;
  final VoidCallback onTap;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final account = summary.account;
    final apr = account.interestRateApr;
    final minPayment = account.minimumPaymentCents;
    final due = account.paymentDueDay;

    return InkWell(
      key: Key('debt_row_tap_${account.id}'),
      onTap: onTap,
      child: ColoredBox(
        color: suggested
            ? AppColors.rowAutoFuture.withValues(alpha: 0.55)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        key: Key('debt_row_${account.id}'),
                        style: textTheme.titleMedium?.copyWith(
                          color: suggested ? AppColors.primaryBright : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (suggested) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.gps_fixed,
                        key: Key('debt_row_target_icon'),
                        size: 18,
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  formatCents(summary.balanceCents),
                  textAlign: TextAlign.end,
                  style: textTheme.titleMedium?.copyWith(
                    fontFamily: AppTheme.monoFont,
                    // Debt registers: positive = owed, negative = credit.
                    color: summary.balanceCents > 0
                        ? AppColors.danger
                        : AppColors.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  apr == null ? '—' : '${apr.toStringAsFixed(2)}%',
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: AppTheme.monoFont,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  minPayment == null ? '—' : formatCents(minPayment),
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: AppTheme.monoFont,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  due == null ? '—' : '$due',
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: AppTheme.monoFont,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
