import 'dart:io';

import 'package:path/path.dart' as p;

import 'vault_files.dart';
import 'vault_meta.dart';

/// Copies an encrypted vault (database + meta) to a destination path (Phase 5.2).
class VaultBackupService {
  /// Suggested backup filename for [asOf] (local calendar day).
  static String suggestedFileName({DateTime? asOf}) {
    final day = asOf ?? DateTime.now();
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'vault-$y$m$d.cfm.db';
  }

  /// Copies [sourceDatabasePath] and its `.meta.json` beside [destDatabasePath].
  ///
  /// Does not copy lock or pending-audit sidecars. Overwrites destination files
  /// when they already exist.
  static Future<void> backupEncryptedVault({
    required String sourceDatabasePath,
    required String destDatabasePath,
  }) async {
    final source = p.normalize(sourceDatabasePath);
    final dest = p.normalize(destDatabasePath);
    if (source == dest) {
      throw ArgumentError('Backup destination must differ from the live vault');
    }
    if (!await VaultFiles.isComplete(source)) {
      throw StateError('Source vault is incomplete (need database + meta)');
    }

    await File(dest).parent.create(recursive: true);
    await File(source).copy(dest);

    final sourceMeta = VaultMeta.pathForDatabase(source);
    final destMeta = VaultMeta.pathForDatabase(dest);
    await File(sourceMeta).copy(destMeta);
  }
}
