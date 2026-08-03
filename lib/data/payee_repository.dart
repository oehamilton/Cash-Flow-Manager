import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'audit_categories.dart';
import 'audit_log_repository.dart';
import 'database_session.dart';
import 'payee.dart';

/// CRUD for managed payees (Phase 6.2).
class PayeeRepository {
  PayeeRepository(this._session, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final DatabaseSession _session;
  final Uuid _uuid;

  Database get _db => _session.database;
  AuditLogRepository get _audit => AuditLogRepository(_session);

  Payee? getById(String id) {
    final rows = _db.select(
      'SELECT * FROM payees WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Payee.fromRow(rows.first);
  }

  Payee? findByName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final rows = _db.select(
      'SELECT * FROM payees WHERE name = ? COLLATE NOCASE LIMIT 1',
      [trimmed],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Payee.fromRow(rows.first);
  }

  List<Payee> listAll({String prefix = ''}) {
    final trimmed = prefix.trim();
    final rows = trimmed.isEmpty
        ? _db.select(
            '''
SELECT * FROM payees
ORDER BY name COLLATE NOCASE ASC
''',
          )
        : _db.select(
            '''
SELECT * FROM payees
WHERE name LIKE ? ESCAPE '\\'
ORDER BY name COLLATE NOCASE ASC
''',
            ['${_likeEscape(trimmed)}%'],
          );
    return rows.map(Payee.fromRow).toList();
  }

  String create(PayeeDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Payee name is required');
    }
    if (findByName(name) != null) {
      throw StateError('A payee named "$name" already exists');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final notes = _nullIfBlank(draft.notes);
    final url = _nullIfBlank(draft.url);
    final phone = _nullIfBlank(draft.phone);

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
INSERT INTO payees (id, name, notes, url, phone, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?)
''',
        [id, name, notes, url, phone, now, now],
      );
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.create,
        entityType: AuditEntityType.payee,
        entityId: id,
        summary: 'Created payee "$name"',
        detail: {'name': name},
      );
      _db.execute('COMMIT');
      return id;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void update(String id, PayeeUpdate patch) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Payee not found');
    }
    final nextName = patch.name?.trim() ?? existing.name;
    if (nextName.isEmpty) {
      throw ArgumentError('Payee name is required');
    }
    final conflict = findByName(nextName);
    if (conflict != null && conflict.id != id) {
      throw StateError('A payee named "$nextName" already exists');
    }
    final nextNotes = patch.clearNotes
        ? null
        : (patch.notes != null ? _nullIfBlank(patch.notes) : existing.notes);
    final nextUrl = patch.clearUrl
        ? null
        : (patch.url != null ? _nullIfBlank(patch.url) : existing.url);
    final nextPhone = patch.clearPhone
        ? null
        : (patch.phone != null ? _nullIfBlank(patch.phone) : existing.phone);
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE payees SET
  name = ?, notes = ?, url = ?, phone = ?, updated_at = ?
WHERE id = ?
''',
        [nextName, nextNotes, nextUrl, nextPhone, now, id],
      );
      // Keep transaction display text in sync when renamed.
      if (nextName != existing.name) {
        _db.execute(
          '''
UPDATE transactions SET payee = ?, updated_at = ?
WHERE payee_id = ?
''',
          [nextName, now, id],
        );
      }
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.update,
        entityType: AuditEntityType.payee,
        entityId: id,
        summary: 'Updated payee "$nextName"',
        detail: {'name': nextName},
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes the payee row; transactions keep payee text and lose payee_id.
  void delete(String id) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Payee not found');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE transactions SET payee_id = NULL, updated_at = ? WHERE payee_id = ?',
        [now, id],
      );
      _db.execute('DELETE FROM payees WHERE id = ?', [id]);
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.delete,
        entityType: AuditEntityType.payee,
        entityId: id,
        summary: 'Deleted payee "${existing.name}"',
        detail: {'name': existing.name},
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Merges [sourceId] into [targetId]: rewrite txs, delete source.
  void merge({required String sourceId, required String targetId}) {
    if (sourceId == targetId) {
      throw ArgumentError('Cannot merge a payee into itself');
    }
    final source = getById(sourceId);
    final target = getById(targetId);
    if (source == null || target == null) {
      throw StateError('Payee not found');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE transactions SET
  payee_id = ?,
  payee = ?,
  updated_at = ?
WHERE payee_id = ?
''',
        [targetId, target.name, now, sourceId],
      );
      _db.execute('DELETE FROM payees WHERE id = ?', [sourceId]);
      _audit.append(
        category: AuditCategory.account,
        action: AuditAction.update,
        entityType: AuditEntityType.payee,
        entityId: targetId,
        summary: 'Merged payee "${source.name}" into "${target.name}"',
        detail: {
          'source_id': sourceId,
          'target_id': targetId,
        },
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  static String _likeEscape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
