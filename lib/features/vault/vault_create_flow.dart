import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../auth/vault_paths.dart';
import '../../theme/app_colors.dart';

/// Asks for a vault name and a save path under Documents\CashFlowManager.
///
/// Returns the chosen database path, or null if cancelled.
Future<String?> runCreateNewVaultFlow(BuildContext context) async {
  final folderName = await showDialog<String>(
    context: context,
    builder: (context) => const _VaultNameDialog(),
  );
  if (folderName == null || folderName.trim().isEmpty) {
    return null;
  }

  final suggested = VaultPaths.suggestedNewVaultDatabasePath(
    folderName: folderName,
  );
  await Directory(p.dirname(suggested)).create(recursive: true);

  const typeGroup = XTypeGroup(
    label: 'Cash Flow Manager vault',
    extensions: <String>['cfm.db', 'db'],
  );
  final location = await getSaveLocation(
    acceptedTypeGroups: const [typeGroup],
    suggestedName: p.basename(suggested),
    initialDirectory: p.dirname(suggested),
    confirmButtonText: 'Create here',
  );
  return location?.path;
}

class _VaultNameDialog extends StatefulWidget {
  const _VaultNameDialog();

  @override
  State<_VaultNameDialog> createState() => _VaultNameDialogState();
}

class _VaultNameDialogState extends State<_VaultNameDialog> {
  final _controller = TextEditingController(text: 'Business');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('vault_create_name_dialog'),
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('New vault'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create a separate encrypted books file (for example Personal '
              'and Business). Suggested location is under Documents.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('vault_create_name_field'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Vault name',
                hintText: 'Business',
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('vault_create_name_continue'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
