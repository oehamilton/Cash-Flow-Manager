import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'register_filter.dart';

/// Compact search + cleared facet + optional date bounds (Phase 2.6).
class RegisterFilterBar extends StatelessWidget {
  const RegisterFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.searchFocusNode,
    this.resultCount,
    this.totalCount,
  });

  final RegisterFilter filter;
  final ValueChanged<RegisterFilter> onChanged;
  final FocusNode searchFocusNode;
  final int? resultCount;
  final int? totalCount;

  String _dateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.dateFrom ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      onChanged(filter.copyWith(dateFrom: picked));
    }
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.dateTo ?? filter.dateFrom ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      onChanged(filter.copyWith(dateTo: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      key: const Key('register_filter_bar'),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        color: AppColors.surface.withValues(alpha: 0.65),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('register_search_field'),
                    focusNode: searchFocusNode,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Payee, memo, or date (2026-08, this week…)',
                      suffixIcon: filter.query.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('register_search_clear'),
                              tooltip: 'Clear search',
                              onPressed: () =>
                                  onChanged(filter.copyWith(query: '')),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                    ),
                    onChanged: (value) =>
                        onChanged(filter.copyWith(query: value)),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<ClearedFilter>(
                  key: const Key('register_cleared_filter'),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: ClearedFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: ClearedFilter.cleared,
                      label: Text('Clr'),
                    ),
                    ButtonSegment(
                      value: ClearedFilter.uncleared,
                      label: Text('Open'),
                    ),
                  ],
                  selected: {filter.cleared},
                  onSelectionChanged: (selected) {
                    onChanged(filter.copyWith(cleared: selected.first));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  key: const Key('register_filter_from'),
                  onPressed: () => _pickFrom(context),
                  child: Text(
                    filter.dateFrom == null
                        ? 'From date'
                        : 'From ${_dateLabel(filter.dateFrom!)}',
                  ),
                ),
                if (filter.dateFrom != null)
                  IconButton(
                    key: const Key('register_filter_from_clear'),
                    tooltip: 'Clear from date',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        onChanged(filter.copyWith(clearDateFrom: true)),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                TextButton(
                  key: const Key('register_filter_to'),
                  onPressed: () => _pickTo(context),
                  child: Text(
                    filter.dateTo == null
                        ? 'To date'
                        : 'To ${_dateLabel(filter.dateTo!)}',
                  ),
                ),
                if (filter.dateTo != null)
                  IconButton(
                    key: const Key('register_filter_to_clear'),
                    tooltip: 'Clear to date',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        onChanged(filter.copyWith(clearDateTo: true)),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                if (filter.isActive)
                  TextButton(
                    key: const Key('register_filter_reset'),
                    onPressed: () => onChanged(const RegisterFilter()),
                    child: const Text('Reset'),
                  ),
                if (resultCount != null && totalCount != null)
                  Text(
                    filter.isActive
                        ? '$resultCount of $totalCount'
                        : '$totalCount rows',
                    key: const Key('register_filter_count'),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                Text(
                  'Ctrl+F search · Ctrl+N add',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
