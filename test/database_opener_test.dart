import 'dart:io';

import 'package:cash_flow_manager/data/database_exceptions.dart';
import 'package:cash_flow_manager/data/database_opener.dart';
import 'package:cash_flow_manager/data/database_session.dart';
import 'package:cash_flow_manager/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_db_');
    dbPath = p.join(tempDir.path, 'vault.cfm.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('creates encrypted schema and reopens with same key', () {
    final created = DatabaseOpener.open(
      databasePath: dbPath,
      passphrase: 'correct-horse-battery',
    );
    final version = created.select('SELECT version FROM schema_version').first;
    expect(version['version'], kSchemaVersion);

    final tables = created
        .select(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .map((r) => r['name'] as String)
        .toList();
    expect(
      tables,
      containsAll([
        'accounts',
        'audit_log',
        'payees',
        'transactions',
        'schema_version',
      ]),
    );
    created.close();

    final reopened = DatabaseOpener.open(
      databasePath: dbPath,
      passphrase: 'correct-horse-battery',
    );
    expect(
      reopened.select('SELECT version FROM schema_version').first['version'],
      kSchemaVersion,
    );
    reopened.close();
  });

  test('wrong passphrase cannot read database', () {
    final created = DatabaseOpener.open(
      databasePath: dbPath,
      passphrase: 'correct-horse-battery',
    );
    created.close();

    expect(
      () => DatabaseOpener.open(
        databasePath: dbPath,
        passphrase: 'wrong-passphrase',
      ),
      throwsA(isA<DatabaseKeyException>()),
    );
  });

  test('session holds lock and closes cleanly', () async {
    final session = await DatabaseSession.open(
      databasePath: dbPath,
      passphrase: 'session-key',
    );
    addTearDown(session.close);
    expect(
      session.database.select('SELECT version FROM schema_version').first['version'],
      kSchemaVersion,
    );

    await expectLater(
      DatabaseSession.open(
        databasePath: dbPath,
        passphrase: 'session-key',
      ),
      throwsA(isA<DatabaseLockedException>()),
    );

    await session.close();

    final again = await DatabaseSession.open(
      databasePath: dbPath,
      passphrase: 'session-key',
    );
    await again.close();
  });
}
