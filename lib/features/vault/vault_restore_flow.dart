import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../auth/vault_backup_service.dart';
import '../../auth/vault_files.dart';
import '../../auth/vault_paths.dart';
import '../../auth/vault_switch_service.dart';
import '../../theme/app_colors.dart';
import 'vault_file_picker.dart';

/// Picks a backup and copies it to a Documents destination.
///
/// Returns the restored database path (not yet activated), or null if cancelled.
Future<String?> runRestoreVaultFlow(BuildContext context) async {
  final initial = await activeVaultInitialDirectory();
  final source = await pickExistingVaultPath(initialDirectory: initial);
  if (source == null) {
    return null;
  }
  await VaultSwitchService.ensureComplete(source);

  final suggested = VaultPaths.suggestedRestoreDatabasePath();
  await Directory(p.dirname(suggested)).create(recursive: true);

  const typeGroup = XTypeGroup(
    label: 'Cash Flow Manager vault',
    extensions: <String>['cfm.db', 'db'],
  );
  final location = await getSaveLocation(
    acceptedTypeGroups: const [typeGroup],
    suggestedName: p.basename(suggested),
    initialDirectory: p.dirname(suggested),
    confirmButtonText: 'Restore here',
  );
  if (location == null) {
    return null;
  }

  final dest = p.normalize(location.path);
  if (await VaultFiles.isComplete(dest)) {
    if (!context.mounted) {
      return null;
    }
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('vault_restore_overwrite_dialog'),
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Replace existing vault?'),
        content: Text(
          'A complete vault already exists at:\n$dest\n\n'
          'Restore will overwrite those files. The backup file itself is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('vault_restore_overwrite_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    if (overwrite != true) {
      return null;
    }
  }

  return VaultBackupService.restoreEncryptedVault(
    sourceDatabasePath: source,
    destDatabasePath: dest,
  );
}
