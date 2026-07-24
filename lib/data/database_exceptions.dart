class DatabaseLockedException implements Exception {
  DatabaseLockedException(this.message, {this.lockPath});

  final String message;
  final String? lockPath;

  @override
  String toString() => 'DatabaseLockedException: $message';
}

class DatabaseKeyException implements Exception {
  DatabaseKeyException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseKeyException: $message';
}

class DatabaseMigrationException implements Exception {
  DatabaseMigrationException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseMigrationException: $message';
}
