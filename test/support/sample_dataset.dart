import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/database_session.dart';
import 'package:uuid/uuid.dart';

/// Result of seeding a deterministic demo vault for tests.
class SampleDatasetResult {
  const SampleDatasetResult({
    required this.primaryAccountId,
    required this.transactionIds,
  });

  final String primaryAccountId;
  final List<String> transactionIds;
}

/// Inserts a small, stable dataset used by harness smoke tests and future
/// register/forecast coverage.
class SampleDataset {
  static PrimaryCheckingDraft get defaultPrimary => PrimaryCheckingDraft(
        name: 'Household Checking',
        institution: 'Demo Credit Union',
        openingBalanceCents: 150000,
        openingDate: DateTime(2026, 7, 1),
      );

  static SampleDatasetResult seed({
    required DatabaseSession session,
    PrimaryCheckingDraft? primary,
    bool withSampleTransactions = true,
    Uuid? uuid,
  }) {
    final ids = uuid ?? const Uuid();
    final draft = primary ?? defaultPrimary;

    final accountId =
        AccountRepository(session, uuid: ids).createPrimaryChecking(draft);

    final transactionIds = <String>[];
    if (withSampleTransactions) {
      transactionIds.addAll(
        _insertSampleTransactions(
          session: session,
          accountId: accountId,
          uuid: ids,
        ),
      );
    }

    return SampleDatasetResult(
      primaryAccountId: accountId,
      transactionIds: transactionIds,
    );
  }

  static List<String> _insertSampleTransactions({
    required DatabaseSession session,
    required String accountId,
    required Uuid uuid,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <(String date, String payee, int amountCents, bool cleared)>[
      ('2026-07-02', 'Payroll', 220000, true),
      ('2026-07-03', 'Grocery Market', -8450, true),
      ('2026-07-05', 'Electric Co', -12500, false),
      ('2026-07-08', 'Transfer to Savings', -50000, false),
    ];

    final ids = <String>[];
    for (final row in rows) {
      final id = uuid.v4();
      ids.add(id);
      session.database.execute(
        '''
INSERT INTO transactions (
  id, account_id, date, payee, memo, amount_cents,
  is_cleared, cleared_at, source, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'manual', ?, ?)
''',
        [
          id,
          accountId,
          row.$1,
          row.$2,
          'Sample dataset',
          row.$3,
          row.$4 ? 1 : 0,
          row.$4 ? now : null,
          now,
          now,
        ],
      );
    }
    return ids;
  }
}
