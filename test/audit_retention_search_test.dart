import 'package:cash_flow_manager/data/app_settings_repository.dart';
import 'package:cash_flow_manager/data/audit_categories.dart';
import 'package:cash_flow_manager/data/audit_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('auditRetentionDays defaults to 365 and persists', () async {
    await harness.createUnlockedVault();
    final settings = AppSettingsRepository(harness.session);
    expect(settings.auditRetentionDays(), 365);

    settings.setAuditRetentionDays(90);
    expect(settings.auditRetentionDays(), 90);

    settings.setAuditRetentionDays(0);
    expect(settings.auditRetentionDays(), 0);
  });

  test('applyRetention deletes rows older than cutoff', () async {
    await harness.createUnlockedVault();
    final repo = AuditLogRepository(harness.session);
    final asOf = DateTime.utc(2026, 7, 24);

    repo.append(
      category: AuditCategory.system,
      action: AuditAction.update,
      summary: 'Old event',
      at: asOf.subtract(const Duration(days: 400)),
    );
    repo.append(
      category: AuditCategory.system,
      action: AuditAction.update,
      summary: 'Recent event',
      at: asOf.subtract(const Duration(days: 10)),
    );

    final removed = repo.applyRetention(365, asOf: asOf);
    expect(removed, greaterThanOrEqualTo(1));

    final summaries = repo.listRecent(limit: 50).map((e) => e.summary).toList();
    expect(summaries, contains('Recent event'));
    expect(summaries, isNot(contains('Old event')));
  });

  test('search matches summary category action and device', () async {
    await harness.createUnlockedVault();
    final repo = AuditLogRepository(
      harness.session,
      machineName: 'Office-PC',
    );
    repo.append(
      category: AuditCategory.transaction,
      action: AuditAction.create,
      summary: 'Created transaction "Costco"',
    );
    repo.append(
      category: AuditCategory.access,
      action: AuditAction.unlockPassword,
      summary: 'Unlocked with password',
    );

    final byPayee = repo.search(query: 'Costco');
    expect(byPayee, isNotEmpty);
    expect(byPayee.every((e) => e.summary.contains('Costco')), isTrue);

    final byCategory = repo.search(query: 'access');
    expect(byCategory, isNotEmpty);
    expect(byCategory.every((e) => e.category == 'access'), isTrue);

    final byDevice = repo.search(query: 'Office');
    expect(byDevice, isNotEmpty);
  });

  test('dollar search finds cents stored in older summaries', () async {
    await harness.createUnlockedVault();
    final repo = AuditLogRepository(harness.session);
    repo.append(
      category: AuditCategory.transaction,
      action: AuditAction.create,
      summary: 'Created transaction "Store" (1275 cents)',
      detail: {'amount_cents': 1275},
    );

    final hits = repo.search(query: '12.75');
    expect(hits, isNotEmpty);
    expect(hits.first.summary, contains('1275'));

    final dollarHits = repo.search(query: r'$12.75');
    expect(dollarHits, isNotEmpty);
  });

  test('search supports paging', () async {
    await harness.createUnlockedVault();
    final repo = AuditLogRepository(harness.session);
    for (var i = 0; i < 30; i++) {
      repo.append(
        category: AuditCategory.system,
        action: AuditAction.update,
        summary: 'Pageable event $i',
      );
    }

    final page0 = repo.search(query: 'Pageable', limit: 10, offset: 0);
    final page1 = repo.search(query: 'Pageable', limit: 10, offset: 10);
    expect(page0, hasLength(10));
    expect(page1, hasLength(10));
    expect(page0.first.id, isNot(page1.first.id));
    expect(repo.count(query: 'Pageable'), greaterThanOrEqualTo(30));
  });

  test('expandSearchTerms includes cents variants', () {
    final terms = AuditLogRepository.expandSearchTerms('12.75');
    expect(terms, contains('12.75'));
    expect(terms, contains('1275'));
    expect(terms, contains('1275 cents'));
  });
}
