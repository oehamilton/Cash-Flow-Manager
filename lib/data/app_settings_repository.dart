import 'database_session.dart';

/// Key/value settings stored in [app_settings] (Phase 5.1+).
class AppSettingsRepository {
  AppSettingsRepository(this._session);

  final DatabaseSession _session;

  static const lockTimeoutMinutesKey = 'lock_timeout_minutes';

  /// Idle auto-lock minutes; `0` means never.
  int lockTimeoutMinutes({int defaultMinutes = 15}) {
    final raw = get(lockTimeoutMinutesKey);
    if (raw == null) {
      return defaultMinutes;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) {
      return defaultMinutes;
    }
    return parsed;
  }

  void setLockTimeoutMinutes(int minutes) {
    if (minutes < 0) {
      throw ArgumentError('lock_timeout_minutes must be >= 0');
    }
    set(lockTimeoutMinutesKey, '$minutes');
  }

  String? get(String key) {
    final rows = _session.database.select(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  void set(String key, String value) {
    _session.database.execute(
      '''
INSERT INTO app_settings (key, value) VALUES (?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value
''',
      [key, value],
    );
  }
}
