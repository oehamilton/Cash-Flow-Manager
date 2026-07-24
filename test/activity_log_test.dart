import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/audit_log_repository.dart';
import 'package:cash_flow_manager/features/settings/activity_log_panel.dart';
import 'package:cash_flow_manager/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_vault.dart';

void main() {
  testWidgets('ActivityLogPanel shows locked copy without session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ActivityLogPanel()),
      ),
    );
    expect(find.byKey(const Key('activity_log_locked')), findsOneWidget);
  });

  test('listRecent returns typed audit entries', () async {
    final harness = TempVaultHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await harness.createUnlockedVault();
    AccountRepository(harness.session).createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 100,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    final repo = AuditLogRepository(harness.session);
    final entries = repo.listRecent(limit: 20);
    expect(entries, isNotEmpty);
    expect(entries.first.summary, isNotEmpty);
    expect(entries.first.machineName, isNotNull);
    expect(entries.first.machineName, isNotEmpty);
    expect(repo.count(), greaterThanOrEqualTo(entries.length));
  });

  testWidgets('SettingsPage shows idle lock and locked activity copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            helloEnabled: false,
            helloAvailable: true,
            lockTimeoutMinutes: 15,
            onLock: () async {},
            onToggleHello: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('settings_lock_timeout_15')), findsOneWidget);
    expect(find.text('Activity log'), findsOneWidget);
    expect(find.byKey(const Key('activity_log_locked')), findsOneWidget);
    expect(
      find.byKey(const Key('settings_audit_retention_365')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_about_button')), findsOneWidget);
  });
}
