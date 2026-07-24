import 'dart:io';

import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/pending_access_audit.dart';
import 'package:cash_flow_manager/data/audit_categories.dart';
import 'package:cash_flow_manager/data/audit_log_repository.dart';
import 'package:cash_flow_manager/data/database_opener.dart';
import 'package:cash_flow_manager/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'support/temp_vault.dart';

void main() {
  group('schema v2', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cfm_audit_schema_');
      dbPath = p.join(tempDir.path, 'vault.cfm.db');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('new vaults create audit_log at schema v2', () {
      final db = DatabaseOpener.open(
        databasePath: dbPath,
        passphrase: 'schema-v2-key',
      );
      addTearDown(db.close);

      expect(
        db.select('SELECT version FROM schema_version').first['version'],
        kSchemaVersion,
      );
      final tables = db
          .select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='audit_log'",
          )
          .map((r) => r['name'] as String);
      expect(tables, contains('audit_log'));
    });

    test('migrates v1 database to v2 with backup', () {
      final raw = sqlite3.open(dbPath);
      try {
        raw.execute("PRAGMA key = 'migrate-key'");
        DatabaseOpener.createV1OnlyForTests(raw);
        expect(
          raw.select('SELECT version FROM schema_version').first['version'],
          1,
        );
      } finally {
        raw.close();
      }

      final migrated = DatabaseOpener.open(
        databasePath: dbPath,
        passphrase: 'migrate-key',
      );
      addTearDown(migrated.close);

      expect(
        migrated.select('SELECT version FROM schema_version').first['version'],
        2,
      );
      expect(File('$dbPath.pre-v1.bak').existsSync(), isTrue);
      expect(
        migrated
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='audit_log'",
            )
            .isNotEmpty,
        isTrue,
      );
    });
  });

  group('access events', () {
    final harness = TempVaultHarness(helloSupported: true);

    setUp(harness.setUp);
    tearDown(harness.tearDown);

    test('create, unlock, lock, hello toggle write audit_log rows', () async {
      await harness.createUnlockedVault();
      var repo = AuditLogRepository(harness.session);
      expect(
        repo.recent().any((e) => e['action'] == AuditAction.createVault),
        isTrue,
      );

      await harness.auth.enableHelloUnlock();
      expect(
        repo.recent().any((e) => e['action'] == AuditAction.helloEnable),
        isTrue,
      );

      await harness.auth.lock();
      await harness.auth.unlockWithPassword(password: harness.password);
      repo = AuditLogRepository(harness.session);
      final actions = repo.recent().map((e) => e['action']).toList();
      expect(actions, contains(AuditAction.lock));
      expect(actions, contains(AuditAction.unlockPassword));

      await harness.auth.disableHelloUnlock();
      expect(
        repo.recent().any((e) => e['action'] == AuditAction.helloDisable),
        isTrue,
      );
    });

    test('failed unlock is queued then flushed on success', () async {
      await harness.createUnlockedVault();
      await harness.auth.lock();

      await expectLater(
        harness.auth.unlockWithPassword(password: 'wrong-password'),
        throwsA(isA<AuthException>()),
      );
      expect(
        await File(
          PendingAccessAudit.pathForDatabase(harness.databasePath),
        ).exists(),
        isTrue,
      );

      await harness.auth.unlockWithPassword(password: harness.password);
      final repo = AuditLogRepository(harness.session);
      final failed = repo.recent().where(
        (e) => e['action'] == AuditAction.unlockFailed,
      );
      expect(failed, isNotEmpty);
      expect(
        failed.first['detail_json'],
        contains('incorrect_password'),
      );
      expect(
        await File(
          PendingAccessAudit.pathForDatabase(harness.databasePath),
        ).exists(),
        isFalse,
      );
    });

    test('detail sanitizer strips password-like keys', () async {
      await harness.createUnlockedVault();
      final repo = AuditLogRepository(harness.session);
      repo.append(
        category: AuditCategory.access,
        action: 'test',
        summary: 'sanitize',
        detail: {
          'password': 'secret',
          'ok': true,
        },
      );
      final row = repo.recent().firstWhere((e) => e['summary'] == 'sanitize');
      expect(row['detail_json'], isNot(contains('secret')));
      expect(row['detail_json'], contains('ok'));
    });
  });
}
