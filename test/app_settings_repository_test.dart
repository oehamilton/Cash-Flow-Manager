import 'package:cash_flow_manager/data/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('lockTimeoutMinutes defaults then persists', () async {
    await harness.createUnlockedVault();
    final settings = AppSettingsRepository(harness.session);
    expect(settings.lockTimeoutMinutes(), 15);

    settings.setLockTimeoutMinutes(30);
    expect(settings.lockTimeoutMinutes(), 30);

    settings.setLockTimeoutMinutes(0);
    expect(settings.lockTimeoutMinutes(), 0);
  });

  test('auditRetentionDays defaults then persists', () async {
    await harness.createUnlockedVault();
    final settings = AppSettingsRepository(harness.session);
    expect(settings.auditRetentionDays(), 365);

    settings.setAuditRetentionDays(730);
    expect(settings.auditRetentionDays(), 730);
  });
}
