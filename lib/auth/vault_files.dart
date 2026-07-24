import 'dart:io';

import 'package:path/path.dart' as p;

import 'vault_meta.dart';

/// What files exist at a vault path.
enum VaultPresence {
  /// No database or metadata.
  none,

  /// Both database and metadata are present (can open).
  complete,

  /// Only one of database/metadata exists (repair via overwrite).
  incomplete,
}

/// Inspect and remove vault sidecar files beside a database path.
class VaultFiles {
  static Future<VaultPresence> presence(String databasePath) async {
    final dbExists = await File(databasePath).exists();
    final metaExists = await File(VaultMeta.pathForDatabase(databasePath)).exists();
    if (!dbExists && !metaExists) {
      return VaultPresence.none;
    }
    if (dbExists && metaExists) {
      return VaultPresence.complete;
    }
    return VaultPresence.incomplete;
  }

  static Future<bool> isComplete(String databasePath) async {
    return await presence(databasePath) == VaultPresence.complete;
  }

  /// Deletes the database, metadata, and lock file if present.
  ///
  /// Does not remove migration backups (`*.pre-vN.bak`).
  static Future<void> deleteVault(String databasePath) async {
    final normalized = p.normalize(databasePath);
    for (final path in [
      normalized,
      VaultMeta.pathForDatabase(normalized),
      '$normalized.cfm.lock',
    ]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
