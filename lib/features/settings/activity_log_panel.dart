import 'package:flutter/material.dart';

import '../../data/audit_log_entry.dart';
import '../../data/audit_log_repository.dart';
import '../../data/database_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Read-only Activity log list for Settings (search + paging).
class ActivityLogPanel extends StatefulWidget {
  const ActivityLogPanel({
    super.key,
    this.session,
    this.pageSize = AuditLogRepository.defaultPageSize,
  });

  final DatabaseSession? session;
  final int pageSize;

  @override
  State<ActivityLogPanel> createState() => _ActivityLogPanelState();
}

class _ActivityLogPanelState extends State<ActivityLogPanel> {
  final _searchController = TextEditingController();
  String _query = '';
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (widget.session == null) {
      return Text(
        'Unlock the vault to view activity.',
        key: const Key('activity_log_locked'),
        style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
      );
    }

    final repo = AuditLogRepository(widget.session!);
    final matchCount = repo.count(query: _query);
    final pageSize = widget.pageSize;
    final pageCount = matchCount == 0 ? 1 : ((matchCount - 1) ~/ pageSize) + 1;
    final page = _page.clamp(0, pageCount - 1);
    if (page != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _page = page);
        }
      });
    }
    final offset = page * pageSize;
    final entries = repo.search(
      query: _query,
      limit: pageSize,
      offset: offset,
    );
    final from = matchCount == 0 ? 0 : offset + 1;
    final to = offset + entries.length;

    return Column(
      key: const Key('activity_log_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('activity_log_search'),
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search activity',
            hintText: 'Payee, device, or amount (e.g. 12.75)',
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const Key('activity_log_search_clear'),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      _setQuery('');
                    },
                    icon: const Icon(Icons.clear, size: 18),
                  ),
          ),
          onChanged: _setQuery,
        ),
        const SizedBox(height: 8),
        Text(
          matchCount == 0
              ? (_query.trim().isEmpty ? '0 events' : '0 matches')
              : 'Showing $from–$to of $matchCount'
                  '${_query.trim().isEmpty ? ' events' : ' matches'}'
                  ' · page ${page + 1} of $pageCount',
          key: const Key('activity_log_count'),
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
            fontFamily: AppTheme.monoFont,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text(
            _query.trim().isEmpty
                ? 'No activity recorded yet.'
                : 'No activity matches this search.',
            key: const Key('activity_log_empty'),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          )
        else
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
        if (matchCount > pageSize) ...[
          const SizedBox(height: 12),
          Row(
            key: const Key('activity_log_pager'),
            children: [
              OutlinedButton(
                key: const Key('activity_log_prev'),
                onPressed: page <= 0
                    ? null
                    : () => setState(() => _page = page - 1),
                child: const Text('Previous'),
              ),
              const Spacer(),
              Text(
                'Page ${page + 1} / $pageCount',
                style: textTheme.bodySmall?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                key: const Key('activity_log_next'),
                onPressed: page >= pageCount - 1
                    ? null
                    : () => setState(() => _page = page + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
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
