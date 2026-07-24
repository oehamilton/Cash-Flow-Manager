import 'package:flutter/material.dart';

import '../../data/audit_log_entry.dart';
import '../../data/audit_log_repository.dart';
import '../../data/database_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Read-only Activity log list for Settings (Phase 5.1).
class ActivityLogPanel extends StatelessWidget {
  const ActivityLogPanel({
    super.key,
    this.session,
    this.limit = 100,
  });

  final DatabaseSession? session;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (session == null) {
      return Text(
        'Unlock the vault to view activity.',
        key: const Key('activity_log_locked'),
        style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
      );
    }

    final repo = AuditLogRepository(session!);
    final entries = repo.listRecent(limit: limit);
    final total = repo.count();

    if (entries.isEmpty) {
      return Text(
        'No activity recorded yet.',
        key: const Key('activity_log_empty'),
        style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
      );
    }

    return Column(
      key: const Key('activity_log_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          total > entries.length
              ? 'Showing ${entries.length} of $total events'
              : '$total events',
          key: const Key('activity_log_count'),
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
            fontFamily: AppTheme.monoFont,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline),
            color: AppColors.surface.withValues(alpha: 0.55),
          ),
          child: Column(
            key: const Key('activity_log_list'),
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: AppColors.outline.withValues(alpha: 0.5),
                  ),
                _ActivityRow(entry: entries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final local = entry.at.toLocal();
    final stamp =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final device = entry.machineName?.trim();
    final deviceLabel =
        (device == null || device.isEmpty) ? 'Unknown device' : device;

    return Padding(
      key: Key('activity_log_row_${entry.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                stamp,
                style: textTheme.bodySmall?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                entry.category,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryBright,
                  fontFamily: AppTheme.monoFont,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  deviceLabel,
                  key: Key('activity_log_device_${entry.id}'),
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontFamily: AppTheme.monoFont,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.summary, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
