/// Read-only audit_log row for the Activity log viewer (Phase 5.1).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.at,
    required this.category,
    required this.action,
    required this.summary,
    this.entityType,
    this.entityId,
    this.detailJson,
    this.machineName,
    this.appVersion,
  });

  final String id;
  final DateTime at;
  final String category;
  final String action;
  final String summary;
  final String? entityType;
  final String? entityId;
  final String? detailJson;
  final String? machineName;
  final String? appVersion;

  factory AuditLogEntry.fromRow(Map<String, Object?> row) {
    return AuditLogEntry(
      id: row['id'] as String,
      at: DateTime.parse(row['at'] as String),
      category: row['category'] as String,
      action: row['action'] as String,
      summary: row['summary'] as String,
      entityType: row['entity_type'] as String?,
      entityId: row['entity_id'] as String?,
      detailJson: row['detail_json'] as String?,
      machineName: row['machine_name'] as String?,
      appVersion: row['app_version'] as String?,
    );
  }
}
