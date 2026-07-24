import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'database_exceptions.dart';
import 'schema.dart';
import 'sql_escape.dart';

/// Opens or creates an encrypted SQLite database (sqlite3mc) and applies schema.
class DatabaseOpener {
  /// Opens [databasePath] with [passphrase], creating the file if needed.
  ///
  /// Uses `journal_mode=DELETE` (safer for cloud-sync folders than WAL).
  static Database open({
    required String databasePath,
    required String passphrase,
  }) {
    if (passphrase.isEmpty) {
      throw DatabaseKeyException('Passphrase must not be empty');
    }

    File(databasePath).parent.createSync(recursive: true);

    final db = sqlite3.open(databasePath);
    try {
      _applyKey(db, passphrase);
      _verifyReadable(db);
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA journal_mode = DELETE');
      _migrate(db, databasePath);
      return db;
    } on Object {
      db.close();
      rethrow;
    }
  }

  static void _applyKey(Database db, String passphrase) {
    // sqlite3mc encryption key — must run before other access.
    db.execute("PRAGMA key = '${escapeSqlString(passphrase)}'");
  }

  static void _verifyReadable(Database db) {
    try {
      db.select('SELECT count(*) AS c FROM sqlite_master');
    } on SqliteException catch (e) {
      throw DatabaseKeyException(
        'Unable to read database with the provided key (${e.message})',
      );
    }
  }

  static void _migrate(Database db, String databasePath) {
    final current = _readSchemaVersion(db);
    if (current == null) {
      _createLatest(db);
      return;
    }
    var version = current;
    if (version == kSchemaVersion) {
      return;
    }
    if (version > kSchemaVersion) {
      throw DatabaseMigrationException(
        'Database schema v$version is newer than this app (v$kSchemaVersion)',
      );
    }

    _backupBeforeMigration(databasePath, version);
    while (version < kSchemaVersion) {
      if (version == 1) {
        _migrateV1ToV2(db);
        version = 2;
        continue;
      }
      throw DatabaseMigrationException(
        'No migration path from schema v$version to v$kSchemaVersion',
      );
    }
  }

  static int? _readSchemaVersion(Database db) {
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'schema_version'",
    );
    if (tables.isEmpty) {
      return null;
    }
    final rows = db.select('SELECT version FROM schema_version LIMIT 1');
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['version'] as int;
  }

  /// Fresh database at the current schema version.
  static void _createLatest(Database db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final sql in SchemaV1.createStatements) {
        db.execute(sql);
      }
      for (final sql in SchemaV2.migrationStatements) {
        db.execute(sql);
      }
      db.execute('INSERT INTO schema_version (version) VALUES (?)', [
        kSchemaVersion,
      ]);
      db.execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Test/helper: create a v1-only database (no audit_log).
  static void createV1OnlyForTests(Database db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final sql in SchemaV1.createStatements) {
        db.execute(sql);
      }
      db.execute('INSERT INTO schema_version (version) VALUES (?)', [1]);
      db.execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static void _migrateV1ToV2(Database db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final sql in SchemaV2.migrationStatements) {
        db.execute(sql);
      }
      db.execute('UPDATE schema_version SET version = ?', [2]);
      db.execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static void _backupBeforeMigration(String databasePath, int fromVersion) {
    final source = File(databasePath);
    if (!source.existsSync()) {
      return;
    }
    final backup = File('$databasePath.pre-v$fromVersion.bak');
    source.copySync(backup.path);
  }

  /// True when the loaded SQLite build exposes cipher pragmas (sqlite3mc/sqlcipher).
  static bool hasCipherSupport(Database db) {
    try {
      db.select('PRAGMA cipher_version');
      return true;
    } on SqliteException {
      return false;
    }
  }
}
