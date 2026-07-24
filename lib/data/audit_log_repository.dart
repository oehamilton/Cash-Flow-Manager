import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../core/app_info.dart';
import 'audit_categories.dart';
import 'database_session.dart';

/// Append-only writer/reader for [audit_log] (no update/delete API).
class AuditLogRepository {
  AuditLogRepository(this._session, {Uuid? uuid, String? machineName})
      : _uuid = uuid ?? const Uuid(),
        _machineName = machineName ?? Platform.localHostname;

  final DatabaseSession _session;
  final Uuid _uuid;
  final String _machineName;

  void append({
    required String category,
    required String action,
    required String summary,
    String? entityType,
    String? entityId,
    Map<String, Object?>? detail,
    DateTime? at,
  }) {
    final id = _uuid.v4();
    final when = (at ?? DateTime.now()).toUtc().toIso8601String();
    final detailJson =
        detail == null ? null : jsonEncode(_sanitizeDetail(detail));

    _session.database.execute(
      '''
INSERT INTO audit_log (
  id, at, category, action, entity_type, entity_id,
  summary, detail_json, machine_name, app_version
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        id,
        when,
        category,
        action,
        entityType,
        entityId,
        summary,
        detailJson,
        _machineName,
        AppInfo.version,
      ],
    );
  }

  /// Access-event helper used by [AuthService].
  void logAccess({
    required String action,
    required String summary,
    Map<String, Object?>? detail,
    DateTime? at,
  }) {
    append(
      category: AuditCategory.access,
      action: action,
      summary: summary,
      entityType: AuditEntityType.vault,
      detail: detail,
      at: at,
    );
  }

  List<Map<String, Object?>> recent({int limit = 50}) {
    final rows = _session.database.select(
      '''
SELECT id, at, category, action, entity_type, entity_id,
       summary, detail_json, machine_name, app_version
FROM audit_log
ORDER BY at DESC, id DESC
LIMIT ?
''',
      [limit],
    );
    return rows
        .map(
          (row) => <String, Object?>{
            'id': row['id'],
            'at': row['at'],
            'category': row['category'],
            'action': row['action'],
            'entity_type': row['entity_type'],
            'entity_id': row['entity_id'],
            'summary': row['summary'],
            'detail_json': row['detail_json'],
            'machine_name': row['machine_name'],
            'app_version': row['app_version'],
          },
        )
        .toList();
  }

  int count() {
    final row = _session.database.select(
      'SELECT COUNT(*) AS c FROM audit_log',
    ).first;
    return row['c'] as int;
  }

  /// Strips any accidental secret-like keys from detail payloads.
  static Map<String, Object?> _sanitizeDetail(Map<String, Object?> detail) {
    const blocked = {
      'password',
      'passphrase',
      'key',
      'secret',
      'salt',
      'token',
    };
    return {
      for (final entry in detail.entries)
        if (!blocked.contains(entry.key.toLowerCase())) entry.key: entry.value,
    };
  }
}
