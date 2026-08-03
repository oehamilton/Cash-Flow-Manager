import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../auth/recent_vault_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Compact recent-vault picker for Unlock / Settings.
class RecentVaultsPanel extends StatelessWidget {
  const RecentVaultsPanel({
    super.key,
    required this.entries,
    required this.activePath,
    required this.onSelect,
    this.onRename,
    this.onRemove,
    this.dense = false,
  });

  final List<RecentVaultEntry> entries;
  final String? activePath;
  final ValueChanged<RecentVaultEntry> onSelect;
  final ValueChanged<RecentVaultEntry>? onRename;
  final ValueChanged<RecentVaultEntry>? onRemove;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final active = activePath == null ? null : p.normalize(activePath!);

    return Column(
      key: const Key('recent_vaults_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recent vaults',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline),
            color: AppColors.surface.withValues(alpha: 0.55),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: AppColors.outline.withValues(alpha: 0.5),
                  ),
                _RecentVaultRow(
                  entry: entries[i],
                  selected: active != null && entries[i].path == active,
                  dense: dense,
                  onSelect: () => onSelect(entries[i]),
                  onRename:
                      onRename == null ? null : () => onRename!(entries[i]),
                  onRemove:
                      onRemove == null ? null : () => onRemove!(entries[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentVaultRow extends StatelessWidget {
  const _RecentVaultRow({
    required this.entry,
    required this.selected,
    required this.dense,
    required this.onSelect,
    this.onRename,
    this.onRemove,
  });

  final RecentVaultEntry entry;
  final bool selected;
  final bool dense;
  final VoidCallback onSelect;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.18)
          : Colors.transparent,
      child: InkWell(
        key: Key('recent_vault_row_${entry.path}'),
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 8 : 10,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.folder : Icons.folder_outlined,
                size: 20,
                color: selected
                    ? AppColors.primaryBright
                    : AppColors.onSurfaceMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      entry.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: AppTheme.monoFont,
                        color: AppColors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRename != null)
                IconButton(
                  key: Key('recent_vault_rename_${entry.path}'),
                  tooltip: 'Rename label',
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              if (onRemove != null)
                IconButton(
                  key: Key('recent_vault_remove_${entry.path}'),
                  tooltip: 'Remove from list',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> promptRecentVaultLabel(
  BuildContext context, {
  required String initialLabel,
}) async {
  final controller = TextEditingController(text: initialLabel);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('recent_vault_rename_dialog'),
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Rename vault label'),
        content: TextField(
          key: const Key('recent_vault_rename_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label',
            helperText: 'Display name only — does not rename the file.',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('recent_vault_rename_save'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
