import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../data/account.dart';
import '../../data/account_repository.dart';
import '../../data/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Debt-focused list: balance, APR, and payment (Phase 1.2).
class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key, required this.auth});

  final AuthService? auth;

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  List<AccountSummary> _rows = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  @override
  void didUpdateWidget(covariant DebtsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth?.session != widget.auth?.session) {
      _reload();
    }
  }

  void _reload({bool initial = false}) {
    final session = widget.auth?.session;
    List<AccountSummary> rows = const [];
    String? error;
    if (session == null) {
      rows = const [];
    } else {
      try {
        rows = AccountRepository(session).listSummaries(debtsOnly: true);
      } on Object catch (e) {
        error = e.toString();
      }
    }
    if (initial) {
      _rows = rows;
      _error = error;
      _loading = false;
      return;
    }
    setState(() {
      _rows = rows;
      _error = error;
      _loading = false;
    });
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debts',
              key: const Key('debts_title'),
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Accounts marked for the debt list, sorted by balance owed. '
              'Use Accounts → Add account to include loans and cards.',
              style: textTheme.bodyLarge,
            ),
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
                          return _DebtRow(summary: _rows[index]);
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
  const _DebtRow({required this.summary});

  final AccountSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final account = summary.account;
    final apr = account.interestRateApr;
    final minPayment = account.minimumPaymentCents;
    final due = account.paymentDueDay;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              account.name,
              key: Key('debt_row_${account.id}'),
              style: textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCents(summary.balanceCents),
              textAlign: TextAlign.end,
              style: textTheme.titleMedium?.copyWith(
                fontFamily: AppTheme.monoFont,
                color: AppColors.danger,
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
    );
  }
}
