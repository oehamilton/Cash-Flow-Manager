import 'dart:convert';
import 'dart:io';

import '../data/audit_categories.dart';
import '../data/audit_log_repository.dart';
import '../data/database_session.dart';

/// Sidecar queue for access events that occur while the vault is locked
/// (e.g. wrong password). Flushed into [audit_log] on the next successful open.
class PendingAccessAudit {
  static String pathForDatabase(String databasePath) =>
      '$databasePath.pending-audit.jsonl';

  static Future<void> enqueue({
    required String databasePath,
    required String action,
    required String summary,
    Map<String, Object?>? detail,
  }) async {
    final file = File(pathForDatabase(databasePath));
    final record = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'action': action,
      'summary': summary,
      'detail': ?detail,
    });
    await file.writeAsString('$record\n', mode: FileMode.append, flush: true);
  }

  static Future<void> enqueueUnlockFailed({
    required String databasePath,
    required String reason,
  }) {
    return enqueue(
      databasePath: databasePath,
      action: AuditAction.unlockFailed,
      summary: 'Unlock failed',
      detail: {'reason': reason},
    );
  }

  /// Writes queued events into [audit_log] and clears the sidecar.
  static Future<void> flush(DatabaseSession session) async {
    final file = File(pathForDatabase(session.databasePath));
    if (!await file.exists()) {
      return;
    }

    final lines = await file.readAsLines();
    final repo = AuditLogRepository(session);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final detail = json['detail'];
      final atRaw = json['at'] as String?;
      repo.logAccess(
        action: json['action'] as String? ?? AuditAction.unlockFailed,
        summary: json['summary'] as String? ?? 'Access event',
        detail: detail is Map
            ? detail.map((key, value) => MapEntry(key.toString(), value))
            : null,
        at: atRaw == null ? null : DateTime.tryParse(atRaw),
      );
    }

    await file.delete();
  }
}
