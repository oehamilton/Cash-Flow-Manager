import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../core/app_info.dart';
import 'audit_categories.dart';
import 'audit_log_entry.dart';
import 'database_session.dart';
import 'money.dart';

/// Append-only writer/reader for [audit_log] (no update/delete API).
class AuditLogRepository {
  AuditLogRepository(this._session, {Uuid? uuid, String? machineName})
      : _uuid = uuid ?? const Uuid(),
        _machineName = machineName ?? Platform.localHostname;

  final DatabaseSession _session;
  final Uuid _uuid;
  final String _machineName;

  /// Default page size for the Activity log UI.
  static const defaultPageSize = 25;

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

  List<Map<String, Object?>> recent({
    int limit = 50,
    int offset = 0,
  }) {
    final rows = _session.database.select(
      '''
SELECT id, at, category, action, entity_type, entity_id,
       summary, detail_json, machine_name, app_version
FROM audit_log
ORDER BY at DESC, id DESC
LIMIT ? OFFSET ?
''',
      [limit, offset],
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

  /// Newest-first entries for the Settings Activity log (read-only).
  List<AuditLogEntry> listRecent({
    int limit = defaultPageSize,
    int offset = 0,
  }) {
    return [
      for (final row in recent(limit: limit, offset: offset))
        AuditLogEntry.fromRow(row),
    ];
  }

  /// Newest-first entries matching [query] across summary/category/action/device/detail.
  ///
  /// Dollar queries like `12.75` also match stored cents (`1275`, `1275 cents`).
  List<AuditLogEntry> search({
    String query = '',
    int limit = defaultPageSize,
    int offset = 0,
  }) {
    final terms = expandSearchTerms(query);
    if (terms.isEmpty) {
      return listRecent(limit: limit, offset: offset);
    }

    final where = _whereForTerms(terms.length);
    final args = <Object?>[
      for (final term in terms) ..._likeArgsForTerm(term),
      limit,
      offset,
    ];
    final rows = _session.database.select(
      '''
SELECT id, at, category, action, entity_type, entity_id,
       summary, detail_json, machine_name, app_version
FROM audit_log
WHERE $where
ORDER BY at DESC, id DESC
LIMIT ? OFFSET ?
''',
      args,
    );
    return [
      for (final row in rows) AuditLogEntry.fromRow(row),
    ];
  }

  int count({String query = ''}) {
    final terms = expandSearchTerms(query);
    if (terms.isEmpty) {
      final row = _session.database.select(
        'SELECT COUNT(*) AS c FROM audit_log',
      ).first;
      return row['c'] as int;
    }
    final where = _whereForTerms(terms.length);
    final args = <Object?>[
      for (final term in terms) ..._likeArgsForTerm(term),
    ];
    final row = _session.database.select(
      'SELECT COUNT(*) AS c FROM audit_log WHERE $where',
      args,
    ).first;
    return row['c'] as int;
  }

  /// Deletes audit rows older than [cutoff] (UTC compare on ISO `at` strings).
  int pruneOlderThan(DateTime cutoff) {
    final before = cutoff.toUtc().toIso8601String();
    final countRow = _session.database.select(
      'SELECT COUNT(*) AS c FROM audit_log WHERE at < ?',
      [before],
    ).first;
    final toDelete = countRow['c'] as int;
    if (toDelete == 0) {
      return 0;
    }
    _session.database.execute(
      'DELETE FROM audit_log WHERE at < ?',
      [before],
    );
    return toDelete;
  }

  /// Applies [retentionDays]; `0` or negative means keep forever.
  int applyRetention(int retentionDays, {DateTime? asOf}) {
    if (retentionDays <= 0) {
      return 0;
    }
    final now = asOf ?? DateTime.now();
    final cutoff = now.toUtc().subtract(Duration(days: retentionDays));
    return pruneOlderThan(cutoff);
  }

  /// Builds LIKE terms for [query], including cents variants of dollar amounts.
  static List<String> expandSearchTerms(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final terms = <String>{trimmed};
    final normalized = trimmed.replaceAll(',', '');
    final money = RegExp(r'^\$?\s*(-?\d+(?:\.\d{1,2})?)\s*$');
    final match = money.firstMatch(normalized);
    if (match != null) {
      try {
        final cents = parseDollarsToCents(match.group(0)!);
        final abs = cents.abs();
        terms.add('$abs');
        terms.add('$abs cents');
        terms.add('-$abs');
        terms.add('-$abs cents');
        terms.add(formatCents(cents));
        terms.add(formatCents(-cents));
        terms.add(formatCents(abs).replaceFirst(r'$', ''));
      } on FormatException {
        // Not a valid amount; keep the raw term only.
      }
    }
    return terms.toList();
  }

  static String _whereForTerms(int termCount) {
    const fieldClause = '''(
  summary LIKE ? ESCAPE '\\'
  OR category LIKE ? ESCAPE '\\'
  OR action LIKE ? ESCAPE '\\'
  OR IFNULL(machine_name, '') LIKE ? ESCAPE '\\'
  OR IFNULL(detail_json, '') LIKE ? ESCAPE '\\'
)''';
    return List.filled(termCount, fieldClause).join(' OR ');
  }

  static List<Object?> _likeArgsForTerm(String term) {
    final pattern = '%${_likeEscape(term)}%';
    return [pattern, pattern, pattern, pattern, pattern];
  }

  static String _likeEscape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
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
