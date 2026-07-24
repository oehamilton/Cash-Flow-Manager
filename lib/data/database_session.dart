import 'package:sqlite3/sqlite3.dart';

import 'app_lock_file.dart';
import 'database_opener.dart';

/// Holds an exclusive lock and an open encrypted database for one app instance.
class DatabaseSession {
  DatabaseSession._({
    required this.databasePath,
    required AppLockFile lockFile,
    required Database openedDatabase,
  })  : _lock = lockFile,
        _database = openedDatabase;

  final String databasePath;
  final AppLockFile _lock;
  final Database _database;
  bool _closed = false;

  Database get database {
    _ensureOpen();
    return _database;
  }

  /// Acquire lock, open/create encrypted DB, migrate schema.
  static Future<DatabaseSession> open({
    required String databasePath,
    required String passphrase,
    bool forceUnlock = false,
  }) async {
    final lockFile = AppLockFile(databasePath);
    await lockFile.acquire(force: forceUnlock);
    try {
      final openedDatabase = DatabaseOpener.open(
        databasePath: databasePath,
        passphrase: passphrase,
      );
      return DatabaseSession._(
        databasePath: databasePath,
        lockFile: lockFile,
        openedDatabase: openedDatabase,
      );
    } on Object {
      await lockFile.release();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _database.close();
    await _lock.release();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('DatabaseSession is closed');
    }
  }
}
