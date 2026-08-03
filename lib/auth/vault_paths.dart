import 'dart:io';

import 'package:path/path.dart' as p;

import 'vault_location_store.dart';

/// Resolves the default encrypted vault location.
class VaultPaths {
  static const String defaultFileName = 'vault.cfm.db';
  static const String appFolderName = 'CashFlowManager';

  /// Active vault path (saved preference) or default under AppData.
  static Future<String> activeDatabasePath() async {
    final saved = await VaultLocationStore.load();
    if (saved != null && saved.isNotEmpty) {
      return p.normalize(saved);
    }
    return defaultDatabasePath();
  }

  /// `%AppData%/CashFlowManager/vault.cfm.db` on Windows.
  static Future<String> defaultDatabasePath() async {
    final root = appDataRoot();
    final dir = Directory(p.join(root, appFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, defaultFileName);
  }

  /// Build a vault file path inside [directory].
  static String databasePathInDirectory(String directory) {
    return p.join(p.normalize(directory), defaultFileName);
  }

  /// Creates parent folders for [databasePath] when missing.
  static Future<void> ensureParentDirectory(String databasePath) async {
    final parent = Directory(p.dirname(p.normalize(databasePath)));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
  }

  /// Test-only override for [appDataRoot].
  static String Function()? debugAppDataRootOverride;

  static String appDataRoot() {
    final override = debugAppDataRootOverride;
    if (override != null) {
      return override();
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return appData;
      }
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return p.join(home, '.local', 'share');
  }
}
