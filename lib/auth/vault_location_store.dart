import 'dart:io';

import 'package:path/path.dart' as p;

import 'recent_vault_store.dart';
import 'vault_paths.dart';

/// Persists the active vault database path (outside the encrypted DB).
class VaultLocationStore {
  static Future<File> _pointerFile() async {
    final root = VaultPaths.appDataRoot();
    final dir = Directory(p.join(root, VaultPaths.appFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'active_vault_path.txt'));
  }

  static Future<String?> load() async {
    final file = await _pointerFile();
    if (!await file.exists()) {
      return null;
    }
    final text = (await file.readAsString()).trim();
    return text.isEmpty ? null : text;
  }

  static Future<void> save(String databasePath) async {
    final normalized = p.normalize(databasePath);
    final file = await _pointerFile();
    await file.writeAsString('$normalized\n');
    await RecentVaultStore.record(normalized);
  }
}
